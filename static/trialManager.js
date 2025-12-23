import { stopTimer } from './utils.js';

export async function saveResponseToServer({
  participantId,
  task,
  answerBrightness,
  answerLength,
  response,
  correct,
  trialNumber,
  timeWhen,
  stimuliNumber,
  duration
}) {
  try {
    await fetch('/save_response', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        task: task,
        answer_brightness: answerBrightness,
        answer_length: answerLength,
        response,
        correct,
        trial_number: trialNumber,
        time_when: timeWhen,
        stimuli_number: stimuliNumber,
        duration
      })
    });
  } catch (error) {
    console.error('Failed to save response:', error);
  }
}

export async function getPracticeData(task, practiceType) {
  try {
    const params = new URLSearchParams({
      task,
      practiceType
    });
    const res = await fetch(`/get_practice?${params.toString()}`, {
      method: 'GET',
      headers: { 'Content-Type': 'application/json' }
    });
    const data = await res.json();
    console.log(data.practice);
    return data.practice;
  } catch (err) {
    console.error('Error fetching practice data:', err);
    return [];
  }
}