import { useState } from 'react';
import { ArrowLeft, ArrowRight, Check, Moon, Sparkles } from 'lucide-react';
import { getMaximumDailyLimit, POLICY_PRESETS } from '../policy.js';
import BrandLogo from './BrandLogo.jsx';

export default function Onboarding({ onComplete }) {
  const [step, setStep] = useState(1);
  const [childName, setChildName] = useState('Alex');
  const [age, setAge] = useState(11);
  const [bedtime, setBedtime] = useState('20:30');
  const [presetId, setPresetId] = useState('balanced');
  const preset = POLICY_PRESETS[presetId];

  const finish = () => onComplete({
    profile: { childName: childName.trim() || 'Alex', age: Number(age), bedtime },
    presetId,
  });

  return (
    <div className="fixed inset-0 z-[100] overflow-y-auto bg-[#f6f7f9] text-slate-950">
      <div className="mx-auto flex min-h-full w-full max-w-xl flex-col justify-center px-5 py-8">
        <div className="mb-8 flex items-center justify-between">
          <div><BrandLogo compact /><div className="mt-1 pl-11 text-xs text-slate-500">Family setup</div></div>
          <div className="text-sm font-semibold text-slate-400">{step} / 3</div>
        </div>

        <div className="rounded-[28px] border border-slate-200 bg-white p-6 shadow-xl shadow-slate-200/60 sm:p-8">
          {step === 1 && (
            <div>
              <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
                <Sparkles size={24} />
              </div>
              <h1 className="text-3xl font-black tracking-tight">Let’s set up your child</h1>
              <p className="mt-2 text-slate-500">Just the essentials. You can change these later.</p>
              <div className="mt-8 space-y-5">
                <label className="block">
                  <span className="text-sm font-bold text-slate-700">Child’s name</span>
                  <input value={childName} onChange={(event) => setChildName(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:border-emerald-500" />
                </label>
                <label className="block">
                  <span className="text-sm font-bold text-slate-700">Age</span>
                  <input type="number" min="5" max="17" value={age} onChange={(event) => setAge(event.target.value)} className="mt-2 w-full rounded-2xl border border-slate-200 px-4 py-3 outline-none focus:border-emerald-500" />
                </label>
                <label className="block">
                  <span className="text-sm font-bold text-slate-700">Usual bedtime</span>
                  <div className="relative mt-2">
                    <Moon className="absolute left-4 top-3.5 text-slate-400" size={18} />
                    <input type="time" value={bedtime} onChange={(event) => setBedtime(event.target.value)} className="w-full rounded-2xl border border-slate-200 py-3 pl-12 pr-4 outline-none focus:border-emerald-500" />
                  </div>
                </label>
              </div>
            </div>
          )}

          {step === 2 && (
            <div>
              <h1 className="text-3xl font-black tracking-tight">Choose a simple plan</h1>
              <p className="mt-2 text-slate-500">These limits apply to entertainment, not schoolwork.</p>
              <div className="mt-7 space-y-3">
                {Object.values(POLICY_PRESETS).map((item) => (
                  <button key={item.id} type="button" onClick={() => setPresetId(item.id)} className={`w-full rounded-2xl border p-5 text-left transition ${presetId === item.id ? 'border-emerald-500 bg-emerald-50 ring-2 ring-emerald-100' : 'border-slate-200 hover:border-slate-300'}`}>
                    <div className="flex items-center justify-between">
                      <div className="font-black">{item.name}</div>
                      {presetId === item.id && <Check size={20} className="text-emerald-600" />}
                    </div>
                    <div className="mt-1 text-sm text-slate-500">{item.description}</div>
                    <div className="mt-4 grid grid-cols-3 gap-2 text-center text-sm">
                      <div className="rounded-xl bg-white p-2"><strong>{getMaximumDailyLimit(item, 'school')}m</strong><span className="block text-xs text-slate-400">School max</span></div>
                      <div className="rounded-xl bg-white p-2"><strong>{getMaximumDailyLimit(item, 'weekend')}m</strong><span className="block text-xs text-slate-400">Weekend max</span></div>
                      <div className="rounded-xl bg-white p-2"><strong>{getMaximumDailyLimit(item, 'holiday')}m</strong><span className="block text-xs text-slate-400">Holiday max</span></div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {step === 3 && (
            <div>
              <div className="mb-6 flex h-12 w-12 items-center justify-center rounded-2xl bg-emerald-50 text-emerald-600">
                <Check size={24} />
              </div>
              <h1 className="text-3xl font-black tracking-tight">Your plan is ready</h1>
              <p className="mt-2 text-slate-500">A clear starting point that your family can review together.</p>
              <div className="mt-7 rounded-2xl bg-slate-950 p-5 text-white">
                <div className="text-sm text-slate-400">{childName || 'Alex'}’s plan</div>
                <div className="mt-1 text-xl font-black">{preset.name}</div>
                <div className="mt-5 space-y-3 text-sm">
                  <div className="flex justify-between"><span className="text-slate-400">School days</span><strong>{preset.schoolLimit} base · {getMaximumDailyLimit(preset, 'school')} max</strong></div>
                  <div className="flex justify-between"><span className="text-slate-400">Weekends</span><strong>{preset.weekendLimit} base · {getMaximumDailyLimit(preset, 'weekend')} max</strong></div>
                  <div className="flex justify-between"><span className="text-slate-400">Holidays</span><strong>{preset.holidayLimit} base · {getMaximumDailyLimit(preset, 'holiday')} max</strong></div>
                  <div className="flex justify-between"><span className="text-slate-400">Entertainment ends</span><strong>1 hour before bed</strong></div>
                </div>
              </div>
              <p className="mt-5 text-xs leading-relaxed text-slate-400">The public-health screen guideline is a ceiling, not a target. TimeBoxer starts with a shorter family allowance.</p>
            </div>
          )}

          <div className="mt-8 flex gap-3">
            {step > 1 && (
              <button type="button" onClick={() => setStep(step - 1)} className="flex items-center justify-center gap-2 rounded-2xl border border-slate-200 px-5 py-3 font-bold text-slate-600 hover:bg-slate-50">
                <ArrowLeft size={18} /> Back
              </button>
            )}
            <button type="button" onClick={() => step === 3 ? finish() : setStep(step + 1)} className="flex flex-1 items-center justify-center gap-2 rounded-2xl bg-[#35d532] px-5 py-3 font-black text-slate-950 hover:bg-emerald-400">
              {step === 3 ? 'Start this plan' : 'Continue'} {step < 3 && <ArrowRight size={18} />}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
