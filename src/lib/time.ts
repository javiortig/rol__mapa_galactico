export function formatCountdown(targetIso?: string | null) {
  if (!targetIso) {
    return "sin crono";
  }

  const diff = new Date(targetIso).getTime() - Date.now();

  if (diff <= 0) {
    return "listo";
  }

  return formatDurationSeconds(Math.ceil(diff / 1000));
}

export function formatDurationSeconds(seconds: number, options: { includeSecondary?: boolean } = {}) {
  const totalSeconds = Math.max(0, Math.ceil(seconds));

  if (totalSeconds <= 0) {
    return "instantáneo";
  }

  if (totalSeconds < 60) {
    return `${totalSeconds} ${totalSeconds === 1 ? "segundo" : "segundos"}`;
  }

  const totalMinutes = Math.ceil(totalSeconds / 60);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;
  const includeSecondary = options.includeSecondary ?? true;

  if (days > 0) {
    if (includeSecondary && hours > 0) {
      return `${days} ${days === 1 ? "día" : "días"} ${hours} ${hours === 1 ? "hora" : "horas"}`;
    }

    return `${days} ${days === 1 ? "día" : "días"}`;
  }

  if (hours > 0) {
    if (includeSecondary && minutes > 0) {
      return `${hours} ${hours === 1 ? "hora" : "horas"} ${minutes} ${minutes === 1 ? "minuto" : "minutos"}`;
    }

    return `${hours} ${hours === 1 ? "hora" : "horas"}`;
  }

  return `${Math.max(1, minutes)} ${minutes === 1 ? "minuto" : "minutos"}`;
}
