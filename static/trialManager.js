export async function saveResponseToServer({
  participantId,
  response,
  correct,
  trialNumber,
  timeWhen,
  stimuliNumber,
  duration,
  responseTime,
  heatmapCondition,
  legendCondition,
  labelCondition,
  attention
}) {
  try {
    await fetch('/save_response', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        response,
        correct,
        trial_number: trialNumber,
        time_when: timeWhen,
        stimuli_number: stimuliNumber,
        duration,
        response_time: responseTime,
        heatmap_condition: heatmapCondition,
        legend_condition: legendCondition,
        label_condition: labelCondition,
        attention
      })
    });
  } catch (error) {
    console.error('Failed to save response:', error);
  }
}

export async function savePracticeSummary({
  participantId,
  practiceAccuracy,
  practiceAccuracyPhone,
  practicePhoneHit,
  practicePhoneMiss,
  practicePhoneFalseAlarm,
  practicePhoneCorrectRejection
}) {
  try {
    await fetch('/save_practice_summary', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        practice_accuracy: practiceAccuracy,
        practice_accuracy_phone: practiceAccuracyPhone,
        hit: practicePhoneHit,
        miss: practicePhoneMiss,
        false_alarm: practicePhoneFalseAlarm,
        correct_rejection: practicePhoneCorrectRejection
      })
    });
  } catch (error) {
    console.error('Failed to save practice summary:', error);
  }
}

export async function savePhoneSummary({
  participantId,
  phoneHit,
  phoneMiss,
  phoneFalseAlarm,
  phoneCorrectRejection
}) {
  try {
    await fetch('/save_phone_summary', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        participant_id: participantId,
        phone_hit: phoneHit,
        phone_miss: phoneMiss,
        phone_false_alarm: phoneFalseAlarm,
        phone_correct_rejection: phoneCorrectRejection
      })
    });
  } catch (error) {
    console.error('Failed to save phone summary:', error);
  }
}
