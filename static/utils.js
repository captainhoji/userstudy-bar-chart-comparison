export function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

let startTime = null;

export function startTimer() {
  startTime = performance.now();
}

export function stopTimer() {
  const endTime = performance.now();
  const duration = endTime - startTime;
  console.log("Duration:", duration.toFixed(2), "ms");
  return duration;
}

export function isDualPhaseTask(taskStr) {
  return taskStr.includes("+");
}

export function splitDualPhaseTask(taskStr) {
  return taskStr.split("+");
}