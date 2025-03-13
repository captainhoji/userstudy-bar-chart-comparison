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

stimuliDir = 'stimuli_red'

participantCounter = 0

with open(stimuliDir + '/stimuli.pickle', 'rb') as file:
    stimuli = pickle.load(file)

with open(stimuliDir + '/practice.pickle', 'rb') as file:
    practice = pickle.load(file)

with open(stimuliDir + '/stimuli_easy.pickle', 'rb') as file:
    practice_easy = pickle.load(file)  

# with open(stimuliDir + '/validation_stimuli_compare_height.pickle', 'rb') as file:
#     validation_stimuli_compare_height = pickle.load(file)  

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
    return render_template('consent.html')

# Verification page
@app.route('/verification')
def verificaiton():
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
        cursor.execute("SELECT COUNT(*) FROM Participant WHERE participant_id = ?", (participant_id,))
        result = cursor.fetchone()
        print("result: ", result)

        if result[0] == 0:
            # New participant
            # Participant not found in db, so insert into table
            cursor.execute("INSERT INTO Participant (participant_id) VALUES (?)", (participant_id,))
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
    participant_id = request.args.get('participant_id')
    return render_template("task.html", participant_id=participant_id)  # Redirect to the task page

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

    if data['message'] == 'initialize':

        label = [False, True]
        layout = ['horizontal', 'vertical']
        global participantCounter

        # Assigning conditions
        if participantCounter % 2 == 0:
            task = "compare_height"
        else:
            task = "compare_index"

        label_idx = (participantCounter//2)%2
        layout_idx = (participantCounter//4)%2

        label = [label[i] for i in [label_idx, label_idx, 1-label_idx, 1-label_idx]]
        layout = [layout[i] for i in [layout_idx, 1-layout_idx, layout_idx, 1-layout_idx]]

        participantCounter += 1

        '''
        Add stimuli
        '''
        indexes_shuffled = []
        difficulty_levels = 3
        stimuli_per_block = 27

        arr = np.arange(stimuli_per_block*4)
        split_arrays = np.split(arr, difficulty_levels ** 2)
        for subarray in split_arrays:
            np.random.shuffle(subarray)
            indexes_shuffled.append(np.split(subarray, 4))
        indexes_shuffled = [np.concatenate(group) for group in zip(*indexes_shuffled)]
        for indexes_in_condition in indexes_shuffled:
            np.random.shuffle(indexes_in_condition)

        indexes_shuffled = [obj.tolist() for obj in indexes_shuffled]
        stimuli_copy = [[stimuli[i] for i in sublist] for sublist in indexes_shuffled]


        # Add engagement checks
        # if task == "compare_height":
        #     validation_stimuli = validation_stimuli_compare_height
        # else:
        #     validation_stimuli = validation_stimuli_compare_index

        # j = 0
        # random.shuffle(validation_stimuli)
        # for i in range(len(validation_stimuli)):
        #     indexes_shuffled[i//5].insert((i%5)*5 + 4, validation_stimuli[i])
        # validation_indexes = [5*i + 4 for i in range(5)]
        # for v_index in validation_indexes:
        #     for i, subgroup in enumerate(indexes_shuffled):
        #         subgroup.insert(v_index, 999)
        #         stimuli_copy[i].insert(v_index, validation_stimuli[j])
        #         j += 1

        
        # swap the answer position with 50% chance
        for i in range(4):
            for j, s in enumerate(stimuli_copy[i]):
                if random.random() < 0.5:
                    s[0], s[1] = s[1], s[0]
                    s[2] = 3-s[2]
                    s[3] = 3-s[3]
                    s[4][0], s[4][1] = s[4][1], s[4][0]
                    indexes_shuffled[i][j] *= -1

        '''
        Add easy practice stimuli
        '''
        for i, s in enumerate(practice_easy):
            if random.random() < 0.5:
                # print("before: ", practice_easy[i])
                s[0], s[1] = s[1], s[0]
                s[4][0], s[4][1] = s[4][1], s[4][0] # swapping the red bar index as well
                s[2] = 3-s[2]
                s[3] = 3-s[3]
                # print("after: ", practice_easy[i])
            # print(f"{i}:, {practice_easy[i]}")
        conditions = {
            "task": task,
            "label": label,
            "layout": layout,
            "stimuli": stimuli_copy,
            "practice_easy": practice_easy,
            "numbers": indexes_shuffled
        }
        return jsonify(conditions)

@app.route('/get_practice')
def getPracticeBlock():
    '''
    Generate practice stimuli and send
    '''
    practices_per_block = 8
    practiceBlock = random.sample(practice, practices_per_block)
    for p in practiceBlock:
        if random.random() < 0.5:
            p[0], p[1] = p[1], p[0]
            p[2] = 3-p[2]
            p[3] = 3-p[3]
            p[4][0], p[4][1] = p[4][1], p[4][0]
    return jsonify({"practice": practiceBlock})

# Save response to database
@app.route('/save_response', methods=['POST'])
def save_response():
    # participant_id: participantId,
    # task: task,
    # response: response, 
    # correct: response == answer ? 1 : 0, 
    # order: trialCounter,
    # time_when: now,
    # orientation: currentLayout,
    # label: currentLabel,
    # stimuli: [stimuli[blockCounter][trialCounter][0], stimuli[blockCounter][trialCounter][1]],
    # number: number
    # duration: duration
    data = request.get_json()
    participant_id = data['participant_id']
    task = data['task']
    response = data['response']
    correct = data['correct']
    trial_number = data['order']
    time_when = data['time_when']
    layout = data['layout']
    label = data['label']
    duration = data['duration']
    stimuli_number = data['number']

    if task == "compare_height":
        task = 0
    else:
        task = 1
    if layout == "horizontal":
        layout = 0
    else:
        layout = 1

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Trial_red_new (participant_id, task, stimuli_number, trial_number, layout, label, correct, response, duration, time_when) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", 
                       (participant_id, task, stimuli_number, trial_number, layout, label, correct, response, duration, time_when))
        conn.commit()
        conn.close()
        print(f'participant {participant_id} trial {trial_number} data saved.')
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400

@app.route("/save_practiceFail", methods=['POST'])
def save_practiceFail():
    data = request.get_json()
    participant_id = data['participant_id']
    orientation = data['orientation']
    label = data['label']
    task = data['task']
    if task == "compare_height":
        task = 0
    else:
        task = 1
    if orientation == "horizontal":
        orientation = 0
    else:
        orientation = 1

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Practice_fail (participant_id, task, orientation, label) VALUES (?, ?, ?, ?)", 
                       (participant_id, task, orientation, label))
        conn.commit()
        conn.close()
        print(f'participant {participant_id} failed easy practice on {task}, {orientation}, {label}. Data saved.')
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400

@app.route("/thank_you")
def thank_you():
    return render_template("thank_you.html")

if __name__ == '__main__':
    app.run(debug=True)
