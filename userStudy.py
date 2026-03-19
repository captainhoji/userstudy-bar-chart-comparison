from flask import Flask, render_template, request, jsonify, redirect, url_for
import pyodbc
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
            # Keep all URL arguments intact from entry link -> task page.
            # This avoids silently dropping newer parameters when we add them.
            task_kwargs = dict(request.args.items())
            task_kwargs['participant_id'] = participant_id
            return redirect(url_for('task', **task_kwargs))
            # return render_template('survey.html', participant_id=participant_id)
        else:
            # participant already exists, so abort
            print(f"Participant '{participant_id}' already exists.")
            return render_template('prolific_id.html', error_message="It looks like you have already participated in this study. You can only take this study once.")

    # directed from just first clicking on the survey link (When method is GET)
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
    return render_template("task.html", participant_id=participant_id)


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


# Save practice summary
@app.route('/save_practice_summary', methods=['POST'])
def save_practice_summary():
    data = request.get_json()
    fields = [
        "participant_id",
        "practice_accuracy",
        "practice_accuracy_phone",
        "hit",
        "miss",
        "false_alarm",
        "correct_rejection"
    ]
    values = [data.get(field) for field in fields]

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Practice_heatmap", fields, values)
        conn.commit()
        conn.close()
        return jsonify({'message': 'Practice summary saved successfully'}), 200

    return jsonify({'message': 'Error saving practice summary'}), 400


@app.route('/save_phone_summary', methods=['POST'])
def save_phone_summary():
    data = request.get_json() or {}
    app.logger.info("save_phone_summary payload: %s", data)
    fields = [
        "participant_id",
        "hit",
        "miss",
        "false_alarm",
        "correct_rejection"
    ]
    values = [
        data.get("participant_id"),
        int(data.get("hit") or 0),
        int(data.get("miss") or 0),
        int(data.get("false_alarm") or 0),
        int(data.get("correct_rejection") or 0)
    ]
    print(values)

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Trial_phone", fields, values)
        conn.commit()
        conn.close()
        return jsonify({'message': 'Phone summary saved successfully'}), 200

    return jsonify({'message': 'Error saving phone summary'}), 400


# Save response to database
@app.route('/save_response', methods=['POST'])
def save_response():
    data = request.get_json()
    trial_type = (data.get("trial_type") or "heatmap").lower()
    if trial_type == "linechart":
        fields = [
            "participant_id",
            "response_time",
            "correct",
            "trial_number",
            "stimuli_number",
            "response",
            "slope",
            "legend",
            "statement_type",
            "statement_truth",
            "comparison_frame",
            "attention",
            "time_when"
        ]
        values = [
            data.get("participant_id"),
            data.get("response_time"),
            data.get("correct"),
            data.get("trial_number"),
            data.get("stimuli_number"),
            data.get("response"),
            data.get("heatmap_condition"),
            data.get("legend_condition"),
            data.get("statement_type"),
            data.get("statement_truth"),
            data.get("comparison_frame"),
            data.get("attention"),
            data.get("time_when")
        ]
        # Bar-chart mode uses the same payload schema for now.
        table_name = "Trial_linechart"
    elif trial_type == "barchart":
        fields = [
            "participant_id",
            "response_time",
            "correct",
            "trial_number",
            "stimuli_number",
            "response",
            "task",
            "color",
            "attention",
            "time_when"
        ]
        values = [
            data.get("participant_id"),
            data.get("response_time"),
            data.get("correct"),
            data.get("trial_number"),
            data.get("stimuli_number"),
            data.get("response"),
            # Frontend currently sends statement_type for barchart task.
            data.get("task") or data.get("statement_type"),
            # Frontend currently sends legend_condition for barchart color condition.
            data.get("color") or data.get("legend_condition"),
            data.get("attention"),
            data.get("time_when")
        ]
        table_name = "Trial_barchart"
    else:
        fields = [
            "participant_id",
            "response_time",
            "correct",
            "trial_number",
            "stimuli_number",
            "response",
            "heatmap_condition",
            "legend_condition",
            "label_condition",
            "attention",
            "time_when"
        ]
        values = [
            data.get("participant_id"),
            data.get("response_time"),
            data.get("correct"),
            data.get("trial_number"),
            data.get("stimuli_number"),
            data.get("response"),
            data.get("heatmap_condition"),
            data.get("legend_condition"),
            data.get("label_condition"),
            data.get("attention"),
            data.get("time_when")
        ]
        table_name = "Trial_heatmap"

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, table_name, fields, values)
        conn.commit()
        conn.close()
        return jsonify({'message': 'Response saved successfully'}), 200

    return jsonify({'message': 'Error saving response'}), 400


@app.route('/save_responses_batch', methods=['POST'])
def save_responses_batch():
    data = request.get_json() or {}
    responses = data.get('responses') or []

    if not isinstance(responses, list) or len(responses) == 0:
        return jsonify({'message': 'No responses provided'}), 400

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        for row in responses:
            trial_type = (row.get("trial_type") or "heatmap").lower()
            if trial_type == "linechart":
                fields = [
                    "participant_id",
                    "response_time",
                    "correct",
                    "trial_number",
                    "stimuli_number",
                    "response",
                    "slope",
                    "legend",
                    "statement_type",
                    "statement_truth",
                    "comparison_frame",
                    "attention",
                    "time_when"
                ]
                values = [
                    row.get("participant_id"),
                    row.get("response_time"),
                    row.get("correct"),
                    row.get("trial_number"),
                    row.get("stimuli_number"),
                    row.get("response"),
                    row.get("heatmap_condition"),
                    row.get("legend_condition"),
                    row.get("statement_type"),
                    row.get("statement_truth"),
                    row.get("comparison_frame"),
                    row.get("attention"),
                    row.get("time_when")
                ]
                table_name = "Trial_linechart"
            elif trial_type == "barchart":
                fields = [
                    "participant_id",
                    "response_time",
                    "correct",
                    "trial_number",
                    "stimuli_number",
                    "response",
                    "task",
                    "color",
                    "attention",
                    "time_when"
                ]
                values = [
                    row.get("participant_id"),
                    row.get("response_time"),
                    row.get("correct"),
                    row.get("trial_number"),
                    row.get("stimuli_number"),
                    row.get("response"),
                    row.get("task") or row.get("statement_type"),
                    row.get("color") or row.get("legend_condition"),
                    row.get("attention"),
                    row.get("time_when")
                ]
                table_name = "Trial_barchart"
            else:
                fields = [
                    "participant_id",
                    "response_time",
                    "correct",
                    "trial_number",
                    "stimuli_number",
                    "response",
                    "heatmap_condition",
                    "legend_condition",
                    "label_condition",
                    "attention",
                    "time_when"
                ]
                values = [
                    row.get("participant_id"),
                    row.get("response_time"),
                    row.get("correct"),
                    row.get("trial_number"),
                    row.get("stimuli_number"),
                    row.get("response"),
                    row.get("heatmap_condition"),
                    row.get("legend_condition"),
                    row.get("label_condition"),
                    row.get("attention"),
                    row.get("time_when")
                ]
                table_name = "Trial_heatmap"
            insert_row(cursor, table_name, fields, values)
        conn.commit()
        conn.close()
        return jsonify({'message': 'Responses saved successfully', 'count': len(responses)}), 200

    return jsonify({'message': 'Error saving responses batch'}), 400


@app.route("/thank_you")
def thank_you():
    return render_template("thank_you.html")


@app.route("/ishihara")
def ishihara():
    participant_id = request.args.get('participant_id', '')
    return render_template("ishihara.html", participant_id=participant_id)


@app.route("/submit_ishihara", methods=["POST"])
def submit_ishihara():
    data = request.get_json() or {}
    participant_id = data.get("participant_id")
    color_difficulty = data.get("colorDifficulty")
    color_blind = data.get("colorBlind")
    device = data.get("device")
    responses = data.get("responses") or []

    total = len(responses)
    correct_count = 0
    for item in responses:
        correct_answer = (item.get("correct_answer") or "").strip().lower()
        response = (item.get("response") or "").strip().lower()
        if correct_answer and response == correct_answer:
            correct_count += 1

    overall_accuracy = round(correct_count / total, 4) if total > 0 else None

    fields = [
        "participant_id",
        "color_difficulty",
        "color_blind",
        "device",
        "overall_accuracy"
    ]
    values = [participant_id, color_difficulty, color_blind, device, overall_accuracy]

    conn = get_db_connection()
    if conn:
        cursor = conn.cursor()
        insert_row(cursor, "Ishihara_test", fields, values)
        conn.commit()
        conn.close()
        return jsonify({"message": "Ishihara responses saved"}), 200

    return jsonify({"message": "Error saving Ishihara responses"}), 400


def insert_row(cursor, table, fields, values):
    sql = f"INSERT INTO {table} ({', '.join(fields)}) VALUES ({', '.join(['?'] * len(fields))})"
    cursor.execute(sql, values)


if __name__ == '__main__':
    app.run(debug=True)
