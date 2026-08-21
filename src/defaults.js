export const DEFAULT_EARN_TASKS = [
  {
    id: 'earn-read',
    title: 'Read',
    duration: 20,
    reward: 5,
    icon: 'BookOpen',
    focusMode: 'screen-free',
  },
  {
    id: 'earn-move',
    title: 'Move & Play',
    duration: 30,
    reward: 10,
    icon: 'Dumbbell',
    focusMode: 'screen-free',
  },
  {
    id: 'earn-create',
    title: 'Create',
    duration: 20,
    reward: 5,
    icon: 'Sparkles',
    focusMode: 'screen-free',
  },
];

export const DEFAULT_SPEND_TASKS = [
  { id: 'spend-1', title: 'Video Games', duration: 20, icon: 'Gamepad2' },
  { id: 'spend-2', title: 'Watch Videos', duration: 20, icon: 'Tv' },
];

const LEGACY_DEFAULT_EARN_TITLES = new Set([
  'Chinese Reading',
  'English Reading',
  'Outdoor Play',
  'Outdoor Sports',
  'HIIT Workout',
]);

const isLegacyDefaultEarnTask = (task) => (
  /^earn-[1-4]$/.test(String(task?.id || ''))
  && LEGACY_DEFAULT_EARN_TITLES.has(task?.title)
  && Number(task?.duration) === 30
  && Number(task?.reward) === 30
);

const isLegacyDefaultSpendTask = (task) => (
  Number(task?.duration) === 30
  && (
    (task?.id === 'spend-1' && task?.title === 'Video Games')
    || (task?.id === 'spend-2' && ['Watch TV', 'Watch Videos'].includes(task?.title))
  )
);

export function migrateEarnTasks(tasks) {
  const currentTasks = Array.isArray(tasks) ? tasks : [];
  const customTasks = currentTasks.filter((task) => (
    !isLegacyDefaultEarnTask(task)
    && !DEFAULT_EARN_TASKS.some((defaultTask) => defaultTask.id === task.id)
  ));

  const existingDefaults = new Map(
    currentTasks
      .filter((task) => DEFAULT_EARN_TASKS.some((defaultTask) => defaultTask.id === task.id))
      .map((task) => [task.id, task]),
  );

  return [
    ...DEFAULT_EARN_TASKS.map((task) => ({ ...task, ...(existingDefaults.get(task.id) || {}) })),
    ...customTasks,
  ];
}

export function migrateSpendTasks(tasks) {
  const currentTasks = Array.isArray(tasks) ? tasks : [];
  if (currentTasks.length === 0) return DEFAULT_SPEND_TASKS.map((task) => ({ ...task }));

  return currentTasks.map((task) => {
    if (isLegacyDefaultSpendTask(task)) {
      return { ...DEFAULT_SPEND_TASKS.find((defaultTask) => defaultTask.id === task.id) };
    }
    const migratedTask = Object.fromEntries(
      Object.entries(task).filter(([key]) => key !== 'cost'),
    );
    return {
      ...migratedTask,
      duration: Number(task.duration) || 20,
    };
  });
}
