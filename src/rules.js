export const MIN_TASK_DURATION = 10;
export const MAX_TASK_DURATION = 180;

export function validateTaskInput({ title, duration, value, type }) {
  const normalizedTitle = String(title ?? '').trim();
  const parsedDuration = Number(duration);
  const parsedValue = Number(value);

  if (!normalizedTitle) {
    return { ok: false, message: 'Task name is required.' };
  }
  if (!Number.isInteger(parsedDuration)) {
    return { ok: false, message: 'Duration must be a whole number of minutes.' };
  }
  if (parsedDuration < MIN_TASK_DURATION) {
    return { ok: false, message: `Duration must be at least ${MIN_TASK_DURATION} minutes.` };
  }
  if (parsedDuration > MAX_TASK_DURATION) {
    return { ok: false, message: `Duration cannot exceed ${MAX_TASK_DURATION} minutes.` };
  }
  if (type === 'earn' && !Number.isInteger(parsedValue)) {
    return { ok: false, message: 'Bonus must be a whole number of minutes.' };
  }
  if (type === 'earn' && parsedValue < 1) {
    return { ok: false, message: 'Bonus must be at least 1 minute.' };
  }
  if (type === 'earn' && parsedValue > parsedDuration) {
    return { ok: false, message: 'Earn reward cannot exceed task duration.' };
  }

  return {
    ok: true,
    title: normalizedTitle,
    duration: parsedDuration,
    value: type === 'earn' ? parsedValue : parsedDuration,
  };
}

export function getPlayedMinutes(durationMinutes, remainingSeconds) {
  const totalSeconds = Math.max(0, Number(durationMinutes) * 60);
  const safeRemaining = Math.min(totalSeconds, Math.max(0, Number(remainingSeconds)));
  return Math.ceil((totalSeconds - safeRemaining) / 60);
}

export function getPlayedMinutesForCountdown(durationMinutes, countdownSeconds, remainingSeconds) {
  const duration = Math.max(0, Number(durationMinutes));
  const totalSeconds = Math.max(1, Number(countdownSeconds));
  const safeRemaining = Math.min(totalSeconds, Math.max(0, Number(remainingSeconds)));
  const elapsedRatio = (totalSeconds - safeRemaining) / totalSeconds;
  return Math.min(Math.ceil(duration), Math.ceil(duration * elapsedRatio));
}
