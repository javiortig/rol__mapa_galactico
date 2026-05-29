export function formatCountdown(targetIso?: string | null) {
  if (!targetIso) {
    return "sin crono";
  }

  const diff = new Date(targetIso).getTime() - Date.now();

  if (diff <= 0) {
    return "listo";
  }

  const totalMinutes = Math.ceil(diff / 60_000);
  const days = Math.floor(totalMinutes / 1440);
  const hours = Math.floor((totalMinutes % 1440) / 60);
  const minutes = totalMinutes % 60;

  if (days > 0) {
    return `${days}d ${hours}h`;
  }

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  }

  return `${minutes}m`;
}
