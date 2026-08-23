export function formatOwnedResourceValue(value: number) {
  return floorResource(value).toLocaleString("es-ES");
}

export function formatCompactOwnedResourceValue(value: number) {
  const floored = floorResource(value);
  const absValue = Math.abs(floored);

  if (absValue >= 1000000) {
    return `${Math.trunc(floored / 1000000).toLocaleString("es-ES")}M`;
  }

  if (absValue >= 1000) {
    return `${Math.trunc(floored / 1000).toLocaleString("es-ES")}k`;
  }

  return floored.toLocaleString("es-ES");
}

function floorResource(value: number) {
  return Math.floor(Number.isFinite(value) ? value : 0);
}
