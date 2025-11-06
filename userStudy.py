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

stimuliDir = 'stimuli_bias'

participantCounter = 0

with open(stimuliDir + '/stimuli.pickle', 'rb') as file:
    stimuli = pickle.load(file)

with open(stimuliDir + '/practice.pickle', 'rb') as file:
    practice = pickle.load(file)

with open(stimuliDir + '/stimuli_easy.pickle', 'rb') as file:
    practice_easy = pickle.load(file)  

with open(stimuliDir + '/validation_stimuli.pickle', 'rb') as file:
    validation_stimuli = pickle.load(file)  

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
    first_task = request.args.get('first_task')
    second_task = request.args.get('second_task')
    return render_template('consent.html', first_task=first_task, second_task=second_task)

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

    # Process and store the responses (add your database logic here)
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
    first_task = request.args.get('first_task', '')
    second_task = request.args.get('second_task', '')
    return render_template("task.html", participant_id=participant_id, first_task=first_task, second_task=second_task)  # Redirect to the task page

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
    first_task_str = data.get('first_task', None)
    second_task_str = data.get('second_task', None) # l = longer, s = shorter, h = higher, w = lower

    global participantCounter

    # Assigning conditions
    if validate_firstTaskStr(first_task_str):
        first_task = decode_firstTaskStr(first_task_str)
    else:
        # if participantCounter % 2 == 0:
        #     first_task = ["darkest", "darkest", "lightest", "lightest"]
        # elif participantCounter % 2 == 1:
        #     first_task = ["lightest", "lightest", "darkest", "darkest"]
        first_task = random.sample(["darkest", "lightest"], 1)
    if validate_secondTaskStr(second_task_str):
        second_task = decode_secondTaskStr(second_task_str)
    else:
        # if participantCounter % 2 == 0:
        #     second_task = ["taller", "shorter", "taller", "shorter"]
        # elif participantCounter % 2 == 1:
        #     second_task = ["shorter", "taller", "shorter", "taller"]
        second_task = random.sample(["taller", "shorter"], 1)
    layout = ['horizontal'] * len(first_task)
    orientation = ['vertical'] * len(first_task)

    participantCounter += 1

    # Add Stimuli
    indexes_shuffled = []
    stimuli_per_block = 32

    shuffled_stimuli, shuffled_index = shuffle_stimuli_in_blocks(stimuli, 4)
    for i in range(4):
        for idx in shuffled_index[i]:
            assert(idx < stimuli_per_block*(i+1))

    # Inject Engagement Checks
    random.shuffle(validation_stimuli)
    for i in range(4):
        for j in range(4):
            shuffled_stimuli[i].insert(j*9+5, validation_stimuli[i*4+j])
            shuffled_index[i].insert(j*9+5, -999)

    '''
    Add easy practice stimuli
    '''
    conditions = {
        "first_task": first_task,
        "second_task": second_task,
        "label": [False] * len(first_task),
        "layout": layout,
        "orientation": orientation,
        "stimuli": shuffled_stimuli[:len(first_task)],
        "practice_easy": practice_easy,
        "numbers": shuffled_index[:len(first_task)]
    }
    return jsonify(conditions)

@app.route('/get_practice')
def getPracticeBlock():
    '''
    Generate practice stimuli and send
    '''
    practices_per_block = 8
    practiceBlock = random.sample(practice, practices_per_block)
    return jsonify({"practice": practiceBlock})

# Save response to database
@app.route('/save_response', methods=['POST'])
def save_response():
    data = request.get_json()
    fields = ["participant_id", "first_task", "second_task", "answer_brightness", "duration", "correct", "trial_number", "stimuli_number", "response", "time_when"]
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
    fields = ["participant_id", "first_task", "second_task"]
    values = [data[field] for field in fields]

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Practice_fail_bias", fields, values)
        conn.commit()
        conn.close()
        print(f"participant {data['participant_id']} failed easy practice on {data['first_task']}, {data['second_task']}. Data saved.")
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400

@app.route("/thank_you")
def thank_you():
    return render_template("thank_you.html")

def shuffle_stimuli_in_blocks(stimuli, num_blocks=4):
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

def validate_firstTaskStr(code):
    if code and (len(code) == 1 or len(code) == 4):
        for ch in code:
            if ch != 'd' and ch != 'l':
                return False
        return True
    return False

def decode_firstTaskStr(code: str) -> list:
    mapping = {'d': 'darkest', 'l': 'lightest'}
    return [mapping[char] for char in code]

def validate_secondTaskStr(code):
    if code and (len(code) == 1 or len(code) == 4):
        for ch in code:
            if ch != 't' and ch != 's':
                return False
        return True
    return False

def decode_secondTaskStr(code: str) -> list:
    mapping = {'t': 'taller', 's': 'shorter'}
    return [mapping[char] for char in code]

if __name__ == '__main__':
    app.run(debug=True)
