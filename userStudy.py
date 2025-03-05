from flask import Flask, render_template, request, jsonify, redirect, url_for
import random
import json
import pyodbc, struct
import pickle
from dotenv import load_dotenv
import os

load_dotenv()

app = Flask(__name__)

# Azure SQL Database connection details
server = os.getenv('DATABASE_URL')
database = os.getenv('DATABASE_NAME')
username = os.getenv('DATABASE_USERNAME')
password = os.getenv('DATABASE_PASSWORD')
driver = '{ODBC Driver 18 for SQL Server}'

stimuliDir = 'stimuli'

participantCounter = 0

with open(stimuliDir + '/stimuli.pickle', 'rb') as file:
    stimuli = pickle.load(file)

with open(stimuliDir + '/practice.pickle', 'rb') as file:
    practice = pickle.load(file)

with open(stimuliDir + '/validation_stimuli_compare_height.pickle', 'rb') as file:
    validation_stimuli_compare_height = pickle.load(file)

with open(stimuliDir + '/validation_stimuli_compare_index.pickle', 'rb') as file:
    validation_stimuli_compare_index = pickle.load(file)

with open(stimuliDir + '/practice_stimuli_compare_height.pickle', 'rb') as file:
    practice_stimuli_compare_height = pickle.load(file)

with open(stimuliDir + '/practice_stimuli_compare_index.pickle', 'rb') as file:
    practice_stimuli_compare_index = pickle.load(file)    

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

# Instructions page
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
    responses = tuple([participant_id] +  ["no answer"] + [request.form.get(f'q{i}') or "no answer" for i in range(1, 6)])

    # Process and store the responses (add your database logic here)
    print("Survey Responses:", *responses)  # Example log

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        cursor.execute("INSERT INTO Followup (participant_id, q1, q2, q3, q4, q5, q6) VALUES (?,?,?,?,?,?,?)", responses)
        conn.commit()
        conn.close()
    else:
        print('db connection error in submit_survey')

    return render_template("thank_you.html")  # Redirect to the task page

# Task page for trials
@app.route('/initialize_task', methods=['POST'])
def initializeTask():
    data = request.get_json()
    participant_id = data['participant_id']

    if data['message'] == 'initialize':

        label = [False, True]
        orientation = ['horizontal', 'vertical']
        whatToAlterFirst = 'orientation'
        global participantCounter

        # Assigning conditions
        # if participantCounter % 2 == 0:
        #     task = "compare_highest"
        # else:
        #     task = "compare_index"

        # label_idx = (participantCounter//2)%2
        # orientation_idx = (participantCounter//4)%2

        # Assigning conditions constrained
        task = "compare_index"
        if random.random() < 0.5:
            label_idx = 0
        else:
            label_idx = 1             
        if random.random() < 0.5:
            orientation_idx = 0
        else:
            orientation_idx = 1

        label = [label[i] for i in [label_idx, label_idx, 1-label_idx, 1-label_idx]]
        orientation = [orientation[i] for i in [orientation_idx, 1-orientation_idx, orientation_idx, 1-orientation_idx]]

        participantCounter += 1

        '''
        Add stimuli
        '''
        stimuli_per_block = 20
        stimuli_copy = list(zip(stimuli[:], range(len(stimuli))))
        random.shuffle(stimuli_copy)
        stimuli_shuffled, indexes_shuffled = map(list, zip(*stimuli_copy))

        # swap the answer position with 50% chance
        for i, s in enumerate(stimuli_shuffled):
            if random.random() < 0.5:
                s[0], s[1] = s[1], s[0]
                s[2] = 3-s[2]
                s[3] = 3-s[3]
                indexes_shuffled[i] *= -1
        stimuliblocks = [stimuli_shuffled[i*stimuli_per_block:(i+1)*stimuli_per_block] for i in range(4)]
        stimulinumbers = [indexes_shuffled[i*stimuli_per_block:(i+1)*stimuli_per_block] for i in range(4)]

        '''
        Add validation stimuli
        '''
        validation_per_block = 5

        if task == "compare_highest":
            validation_checks = validation_stimuli_compare_height
        elif task == "compare_index":
            validation_checks = validation_stimuli_compare_index

        random.shuffle(validation_checks)
        j = 0 # validation stimuli counter
        for i in range(len(stimuliblocks)):
            validation_check_indexes = random.sample(range(1, stimuli_per_block+validation_per_block), validation_per_block)
            validation_check_indexes.sort()
            for pos in validation_check_indexes:
                stimuliblocks[i].insert(pos, validation_checks[j])
                stimulinumbers[i].insert(pos, 999) #999 is the code for validation check stimuli
                j += 1
        '''
        Add easy practice stimuli
        '''
        if task == "compare_highest":
            practice_easy = practice_stimuli_compare_height
        elif task == "compare_index":
            practice_easy = practice_stimuli_compare_index
        random.shuffle(practice_easy)

        conditions = {
            "task": task,
            "label": label,
            "orientation": orientation,
            "whatToAlterFirst": whatToAlterFirst,
            "stimuli": stimuliblocks,
            # "practice": practiceblocks,
            "practice_easy": practice_easy,
            "numbers": stimulinumbers
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
    orientation = data['orientation']
    label = data['label']
    stimuli_data = data['stimuli']
    duration = data['duration']
    stimuli_number = data['number']

    stimuli_str = " ".join(str(x) for x in stimuli_data[0]) + "," + " ".join(str(x) for x in stimuli_data[1])
    if task == "compare_highest":
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
        cursor.execute("INSERT INTO Trial (participant_id, task, stimuli_data, stimuli_number, trial_number, orientation, label, correct, response, duration, time_when) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", 
                       (participant_id, task, stimuli_str, stimuli_number, trial_number, orientation, label, correct, response, duration, time_when))
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
    if task == "compare_highest":
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
