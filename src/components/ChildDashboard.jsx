import {
  BookOpen,
  ChevronRight,
  Dumbbell,
  Gamepad2,
  Hourglass,
  LockKeyhole,
  Moon,
  Settings,
  ShieldCheck,
  Sparkles,
  TimerReset,
  Tv,
} from 'lucide-react';
import { DAY_TYPES } from '../policy.js';
import BrandLogo from './BrandLogo.jsx';

const ICONS = { BookOpen, Dumbbell, Gamepad2, Tv, Sparkles };

export default function ChildDashboard({
  profile,
  policy,
  dayType,
  dailyLimit,
  baseDailyLimit,
  todaySpent,
  todayAvailable,
  earnedMinutesToday,
  earnBonusCap,
  cooldownRemaining,
  bedtimeCutoff,
  bedtimeBlocked,
  earnTasks,
  spendTasks,
  pendingRequest,
  onEarn,
  onSpend,
  onRequestExtra,
  onOpenParent,
}) {
  const progress = dailyLimit ? Math.min(100, (todaySpent / dailyLimit) * 100) : 100;
  const isCoolingDown = cooldownRemaining > 0;
  const cooldownMinutes = Math.max(1, Math.ceil(cooldownRemaining / 60000));
  const isBlocked = bedtimeBlocked || isCoolingDown || todayAvailable <= 0;
  const earnBonusRemaining = Math.max(0, earnBonusCap - earnedMinutesToday);
  const isEarnComplete = earnBonusRemaining <= 0;

  return (
    <div className="min-h-[100dvh] bg-[#f8faf8] text-slate-950">
      <header className="border-b border-slate-200/80 bg-white">
        <div className="mx-auto grid max-w-7xl grid-cols-[1fr_auto_1fr] items-center gap-3 px-5 py-4">
          <div className="hidden text-sm font-semibold text-slate-500 sm:block">{profile.childName}’s space</div>
          <BrandLogo />
          <button onClick={onOpenParent} className="justify-self-end flex items-center gap-2 rounded-2xl border border-slate-200 bg-white px-4 py-2.5 text-sm font-bold text-slate-600 shadow-sm transition hover:border-emerald-300 hover:text-emerald-700">
            <Settings size={17} /> Parent
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-5 py-6 sm:py-8">
        <section className="grid gap-4 lg:grid-cols-3">
          <div className="rounded-[26px] border border-slate-200 bg-white p-6 shadow-sm">
            <div className="flex items-center gap-2 text-sm font-black text-emerald-600"><Sparkles size={17} /> {DAY_TYPES[dayType]} plan</div>
            <div className="mt-5 text-2xl font-black">{dayType === 'weekend' ? 'Saturday & Sunday' : DAY_TYPES[dayType]}</div>
            <div className="mt-1 text-sm text-slate-400">{baseDailyLimit} base + up to {earnBonusCap} earned</div>
          </div>

          <div className="rounded-[26px] border border-emerald-100 bg-white p-6 shadow-sm">
            <div className="flex items-center gap-5">
              <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-3xl bg-emerald-50 text-emerald-500"><TimerReset size={32} /></div>
              <div>
                <div className="text-5xl font-black tracking-[-0.06em] text-[#35d532]">{todayAvailable}</div>
                <div className="mt-1 text-sm font-bold text-slate-500">minutes available</div>
              </div>
            </div>
            <div className="mt-4 text-xs text-slate-400">{earnedMinutesToday} of {earnBonusCap} bonus minutes earned today.</div>
          </div>

          <div className="rounded-[26px] border border-slate-200 bg-white p-6 shadow-sm">
            <div className="flex items-center justify-between text-sm"><span className="font-bold text-slate-500">Used today</span><strong>{todaySpent} / {dailyLimit} min</strong></div>
            <div className="mt-4 h-3 overflow-hidden rounded-full bg-slate-100"><div className="h-full rounded-full bg-[#35d532] transition-all" style={{ width: `${progress}%` }} /></div>
            <div className="mt-5 flex items-center gap-2 text-xs text-slate-400"><Moon size={15} /> Entertainment closes at {bedtimeCutoff}</div>
          </div>
        </section>

        {(bedtimeBlocked || isCoolingDown) && (
          <div className="mt-5 flex items-center gap-3 rounded-2xl border border-amber-200 bg-amber-50 p-4 text-amber-900">
            {bedtimeBlocked ? <Moon size={20} /> : <Hourglass size={20} />}
            <div>
              <div className="font-black">{bedtimeBlocked ? 'Entertainment is finished for today' : 'Time for an eye break'}</div>
              <div className="text-sm opacity-70">{bedtimeBlocked ? `Your plan stops one hour before the ${profile.bedtime} bedtime.` : `About ${cooldownMinutes} minute${cooldownMinutes === 1 ? '' : 's'} left before play unlocks.`}</div>
            </div>
          </div>
        )}

        <div className="mt-5 grid gap-5 lg:grid-cols-[1.15fr_0.85fr]">
          <section className="rounded-[28px] border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
            <div className="mb-5 flex items-end justify-between gap-4">
              <div><div className="text-xs font-black uppercase tracking-[0.2em] text-emerald-600">Earn</div><h2 className="mt-1 text-2xl font-black tracking-tight">Choose something useful</h2></div>
              <div className="hidden text-sm text-slate-400 sm:block">{isEarnComplete ? 'Today’s bonus is complete' : `${earnBonusRemaining} bonus min left`}</div>
            </div>
            <div className="space-y-3">
              {earnTasks.map((task) => {
                const Icon = ICONS[task.icon] || Sparkles;
                return (
                  <button key={task.id} onClick={() => onEarn(task)} disabled={isEarnComplete} className={`group flex w-full items-center gap-4 rounded-2xl border p-4 text-left transition ${isEarnComplete ? 'cursor-not-allowed border-slate-200 bg-slate-50 text-slate-400' : 'border-slate-200 bg-white hover:border-emerald-300 hover:bg-emerald-50/30 hover:shadow-md'}`}>
                    <div className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl ${isEarnComplete ? 'bg-white text-slate-300' : 'bg-emerald-50 text-[#35d532]'}`}><Icon size={23} /></div>
                    <div className="min-w-0 flex-1"><div className="truncate font-black">{task.title}</div><div className="mt-1 text-sm text-slate-400">{task.duration} min target</div></div>
                    <div className={`font-black ${isEarnComplete ? 'text-slate-300' : 'text-[#35d532]'}`}>{isEarnComplete ? 'Done' : `+${Math.min(task.reward, earnBonusRemaining)}m`}</div>
                    <ChevronRight size={18} className="text-slate-300 transition group-hover:translate-x-1" />
                  </button>
                );
              })}
            </div>
          </section>

          <section className="rounded-[28px] border border-slate-200 bg-white p-5 shadow-sm sm:p-6">
            <div className="mb-5">
              <div className="text-xs font-black uppercase tracking-[0.2em] text-violet-500">Play</div>
              <h2 className="mt-1 text-2xl font-black tracking-tight">Use your time</h2>
              <div className="mt-1 text-sm text-slate-400">Maximum {policy.maxSessionMinutes} min at once</div>
              <div className="mt-3 flex items-center gap-2 rounded-xl bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-700">
                <ShieldCheck size={16} /> Entertainment apps and selected websites unlock only while a Play timer is running.
              </div>
            </div>
            <div className="space-y-3">
              {spendTasks.map((task) => {
                const Icon = ICONS[task.icon] || Gamepad2;
                return (
                  <button key={task.id} onClick={() => onSpend(task)} disabled={isBlocked} className={`flex w-full items-center gap-4 rounded-2xl border p-5 text-left transition ${isBlocked ? 'cursor-not-allowed border-slate-200 bg-slate-50 text-slate-400' : 'border-violet-100 bg-white hover:border-violet-300 hover:bg-violet-50/40 hover:shadow-md'}`}>
                    <div className={`flex h-14 w-14 shrink-0 items-center justify-center rounded-2xl ${isBlocked ? 'bg-white text-slate-400' : 'bg-violet-50 text-violet-500'}`}><Icon size={26} /></div>
                    <div className="flex-1"><div className="font-black">{task.title}</div><div className="mt-1 text-sm text-slate-400">Play up to {Math.min(task.duration, policy.maxSessionMinutes, todayAvailable)} minutes</div></div>
                    {isBlocked ? <LockKeyhole size={20} /> : <ChevronRight size={20} className="text-slate-300" />}
                  </button>
                );
              })}
            </div>
          </section>
        </div>

        <section className="mt-5 flex flex-col items-center justify-between gap-4 rounded-[28px] border border-emerald-100 bg-white p-5 shadow-sm sm:flex-row sm:px-7">
          <div className="flex items-center gap-4"><div className="flex h-14 w-14 items-center justify-center rounded-full border-2 border-[#35d532] text-lg font-black text-[#35d532]">+10</div><div><div className="text-lg font-black">Ask for 10 min</div><div className="text-sm text-slate-400">Need a little more time? Send one simple request to your parent.</div></div></div>
          <button onClick={onRequestExtra} disabled={pendingRequest?.status === 'pending'} className="rounded-2xl bg-[#35d532] px-6 py-3 text-sm font-black text-slate-950 shadow-sm transition hover:bg-emerald-400 disabled:bg-slate-200 disabled:text-slate-500">
            {pendingRequest?.status === 'pending' ? 'Waiting for parent…' : 'Ask now'}
          </button>
        </section>
      </main>
    </div>
  );
}
