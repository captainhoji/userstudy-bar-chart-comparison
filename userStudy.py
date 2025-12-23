from flask import Flask, render_template, request, jsonify, redirect, url_for
import numpy as np
import random
import json
import pyodbc, struct
import pickle
from dotenv import load_dotenv
import os
import logging
import sys
import string
from pathlib import Path

load_dotenv()

app = Flask(__name__)

logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
app.logger.setLevel(logging.DEBUG)

# Azure SQL Database connection details
server = os.getenv('DATABASE_URL')
database = os.getenv('DATABASE_NAME')
username = os.getenv('DATABASE_USERNAME')
password = os.getenv('DATABASE_PASSWORD')
driver = '{ODBC Driver 18 for SQL Server}'

stimuliColorLengthDir = 'stimuli_bias/color-length'
stimuliLengthColorDir = 'stimuli_bias/length-color'
stimuliSingleTaskDir = 'stimuli_bias/single-task'

participantCounter = 0

datasets = {
    "color-length": stimuliColorLengthDir,
    "length-color": stimuliLengthColorDir,
    "single-task": stimuliSingleTaskDir,
}

files = {
    "stimuli": "stimuli.pickle",
    "practice_hard": "practice.pickle",
    "practice_easy": "stimuli_easy.pickle",
    "validation": "validation_stimuli.pickle",
}

def getTaskType(taskStr):
    if taskStr in {'darkest+taller', 'darkest+shorter', 'lightest+taller', 'lightest+shorter'}:
        return "color-length"
    elif taskStr in {'tallest+darker', 'tallest+lighter', 'shortest+darker', 'shortest+lighter'}:
        return "length-color"
    else:
        return "single-task"

def load_pickle(dir_path, filename):
    with open(Path(dir_path) / filename, "rb") as f:
        return pickle.load(f)

stimuli = {}
for task, directory in datasets.items():
    stimuli[task] = {}
    for key, filename in files.items():
        stimuli[task][key] = load_pickle(directory, filename)


# with open(stimuliDir + '/validation_stimuli_compare_index.pickle', 'rb') as file:
#     validation_stimuli_compare_index = pickle.load(file)  

# Function to establish database connection
def get_db_connection():
    conn_str = f'DRIVER={driver};SERVER={server};DATABASE={database};UID={username};PWD={password}'
    try:
        conn = pyodbc.connect(conn_str)
        return conn
    except Exception as e:
        print(f"Database connection error: {e}")
        return None

# Instructions page
@app.route('/')
def instructions():
    task = request.args.get('task')
    return render_template('consent.html', task=task)

# Verification page
@app.route('/verification')
def verification():
    return render_template('verification.html')

# Survey page
@app.route('/prolific_id', methods=['GET', 'POST'])
def prolific_id():
    # directed from clicking the "submit" button
    if request.method == 'POST':
        participant_id = request.form['participant_id']

        conn = get_db_connection()
        if conn is None:
            print("Database connection failed.")
        cursor = conn.cursor()

        # Check if participant_id exists
        cursor.execute("SELECT COUNT(*) FROM Participant_bias WHERE participant_id = ?", (participant_id,))
        result = cursor.fetchone()
        print("result: ", result)

        if result[0] == 0:
            # New participant
            # Participant not found in db, so insert into table
            cursor.execute("INSERT INTO Participant_bias (participant_id) VALUES (?)", (participant_id,))
            conn.commit()
            conn.close()
            print(f"Participant '{participant_id}' added.")
            return render_template('survey.html', participant_id=participant_id)
        else:
            # participant already exists, so abort
            print(f"Participant '{participant_id}' already exists.")
            return render_template('prolific_id.html', error_message="It looks like you have already participated in this study. You can only take this study once.")

    # directed from just first clicking on the survey link
    return render_template('prolific_id.html')

@app.route('/survey', methods=['GET', 'POST'])
def survey():
    if request.method == 'POST':
        participant_id = request.form.get("participant_id")
        return render_template('survey.html', participant_id=participant_id)
    else:
        return render_template('survey.html', participant_id="testId")

@app.route("/submit_survey", methods=["POST"])
def submit_survey():
    # Retrieve form data
    q1 = request.form.get("q1")
    q2 = request.form.get("q2")
    participant_id = request.form.get("participant_id")

    # Process and store the responses
    print("Survey Responses:", participant_id, q1, q2)  # Example log

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()

        update_query = "UPDATE Survey SET q1 = ?, q2 = ? WHERE participant_id = ?"
        cursor.execute(update_query, (q1, q2, participant_id))

        # Step 2: If no rows were updated, insert a new one
        if cursor.rowcount == 0:
            insert_query = """
            INSERT INTO Survey (participant_id, q1, q2)
            VALUES (?, ?, ?)
            """
            cursor.execute(insert_query, (participant_id, q1, q2))
            conn.commit()
            conn.close()
    else:
        print('db connection error in submit_survey')

    return redirect(url_for('task', participant_id=participant_id))

@app.route('/task')
def task():
    participant_id = request.args.get('participant_id', '')
    if participant_id == '':
        participant_id = 'pilot_' + ''.join(random.choices(string.ascii_letters + string.digits, k=50))
    task = request.args.get('task', '')
    return render_template("task.html", participant_id=participant_id, task=task)  # Redirect to the task page

@app.route('/follow_up', methods=['GET'])
def followup():
    participant_id = request.args.get('participant_id') or "lost"
    return render_template('followup.html', participant_id=participant_id)

@app.route("/submit_followup", methods=["POST"])
def submit_followup():
    participant_id = request.form.get("participant_id")
    responses = tuple([participant_id] + [request.form.get(f'q{i}') or "0" for i in range(1, 5)])

    # Process and store the responses (add your database logic here)
    print("Survey Responses:", *responses)  # Example log

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Followup_red (participant_id, q1, q2, q3, q4) VALUES (?,?,?,?,?)", responses)
        conn.commit()
        conn.close()
    else:
        print('db connection error in submit_survey')

    return redirect(url_for('thank_you'))

# Task page for trials
@app.route('/initialize_task', methods=['POST'])
def initializeTask():
    data = request.get_json()
    participant_id = data['participant_id']
    task_str = data.get('task', None)
    # second_task_str = data.get('second_task', None) # l = longer, s = shorter, h = higher, w = lower

    global participantCounter

    # Assigning conditions
    if validate_taskStr(task_str):
        task = decode_taskStr(task_str)
    else:
        task = random.sample(["darkest+taller", "darkest+shorter", "lightest+taller", "lightest+shorter"], 1)
        task += random.sample([["darkest", "lightest"], ["lightest", "darkest"], ["tallest", "shortest"], ["shortest", "tallest"]], 1)[0]
        task += random.sample(["tallest+darker", "tallest+lighter", "shortest+darker", "shortest+lighter"], 1)


    layout = ['horizontal'] * len(task)
    orientation = ['vertical'] * len(task)


    participantCounter += 1

    # Add Stimuli
    indexes_shuffled = []
    stimuli_per_block = 32

    shuffled_stimuli = []
    shuffled_index = []

    for key in task:
        s, i = prepare_stimuli(stimuli[getTaskType(key)], 1)
        shuffled_stimuli.extend(s)
        shuffled_index.extend(i)

    '''
    Add easy practice stimuli
    '''
    conditions = {
        "task": task,
        "label": [False] * len(task),
        "layout": layout,
        "orientation": orientation,
        "stimuli": shuffled_stimuli[:len(task)],
        "numbers": shuffled_index[:len(task)]
    }
    return jsonify(conditions)

@app.route('/get_practice', methods=['GET'])
# Generate practice stimuli and send
def getPracticeBlock():
    task = request.args.get("task")
    practiceType = "practice_" + request.args.get("practiceType")
    if practiceType == 'practice_hard':
        practices_per_block = 8
    else:
        practices_per_block = 30
    taskType = getTaskType(task)
    print(task)
    print(taskType)
    practiceBlock = random.sample(stimuli[taskType][practiceType], practices_per_block)
    return jsonify({"practice": practiceBlock})

# Save response to database
@app.route('/save_response', methods=['POST'])
def save_response():
    data = request.get_json()
    print(data)
    fields = ["participant_id", "task", "answer_brightness", "answer_length", "duration", "correct", "trial_number", "stimuli_number", "response", "time_when"]
    values = [data[field] for field in fields]

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Trial_bias", fields, values)
        conn.commit()
        conn.close()
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400

@app.route("/save_practiceFail", methods=['POST'])
def save_practiceFail():
    data = request.get_json()
    fields = ["participant_id", "task"]
    values = [data[field] for field in fields]

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Practice_fail_bias", fields, values)
        conn.commit()
        conn.close()
        print(f"participant {data['participant_id']} failed easy practice on {data['task']}. Data saved.")
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400

@app.route("/thank_you")
def thank_you():
    return render_template("thank_you.html")

def prepare_stimuli(stimuliSet, num_blocks):
    shuffled_stimuli, shuffled_index = shuffle_stimuli_in_blocks(stimuliSet["stimuli"], num_blocks)
    for i in range(num_blocks):
        for idx in shuffled_index[i]:
            assert(idx < len(shuffled_stimuli[0])*(i+1))

    # Inject Engagement Checks
    random.shuffle(stimuliSet["validation"])
    for i in range(num_blocks):
        for j in range(4):
            shuffled_stimuli[i].insert(j*9+5, stimuliSet["validation"][i*4+j])
            shuffled_index[i].insert(j*9+5, -999)
    return shuffled_stimuli, shuffled_index

def shuffle_stimuli_in_blocks(stimuli, num_blocks=1):
    block_size = len(stimuli) // num_blocks
    shuffled_stimuli = []
    index_mapping = []

    for i in range(num_blocks):
        start = i * block_size
        end = start + block_size
        block = stimuli[start:end]

        # Add index tracking
        indexed_block = list(enumerate(block, start=start))

        # Shuffle the block
        random.shuffle(indexed_block)

        # Unzip to get back to stimuli and indexes
        indices, shuffled_block = map(list, zip(*indexed_block))

        shuffled_stimuli.append(shuffled_block)
        index_mapping.append(indices)

    return shuffled_stimuli, index_mapping

def insert_row(cursor, table, fields, values):
    sql = f"INSERT INTO {table} ({', '.join(fields)}) VALUES ({', '.join(['?'] * len(fields))})"
    cursor.execute(sql, values)

def validate_taskStr(code):
    if code:
        codes = code.split("-")
        for ch in codes:
            if ch not in ["dt", "ds", "lt", "ls", "td", "tl", "sd", "sl", "t", "s", "d", "l", "r"]:
                return False
        return True
    return False

def decode_taskStr(code: str) -> list:
    codes = code.split("-")
    for i in range(len(codes)):
        if codes[i] == 'r':
            if i == 0:
                codes[i] = random.choice(['dt', 'ds', 'lt', 'ls'])
            elif i == 1:
                codes[i] = random.choice(['t', 's', 'd', 'l'])
            elif i == 2:
                if codes[1] == 't':
                    codes[i] = 's'
                elif codes[1] == 's':
                    codes[i] = 't'
                elif codes[1] == 'd':
                    codes[i] = 'l'
                elif codes[1] == 'l':
                    codes[i] = 'd'
            elif i == 3:
                codes[i] = random.choice(['td', 'tl', 'sd', 'sl'])
    
    mapping = {
        'd': 'darkest', 'l': 'lightest', 't': 'tallest', 's': 'shortest', 
        'dt': 'darkest+taller', 'ds': 'darkest+shorter', 'lt': 'lightest+taller', 'ls':'lightest+shorter',
        'td': 'tallest+darker', 'tl': 'tallest+lighter', 'sd': 'shortest+darker', 'sl':'shortest+lighter',
        'r': 'random'
    }
    return [mapping[char] for char in codes]

if __name__ == '__main__':
    app.run(debug=True)
