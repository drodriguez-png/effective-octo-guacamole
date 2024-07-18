export const cuttingTimeStr = (runtime: number): string => {
  const hours = Math.floor(runtime / 3600);
  const minutes = Math.floor(runtime / 60) % 60;
  const seconds = Math.round(runtime % 60);

  return `${hours}:${minutes}:${seconds}`;
};
