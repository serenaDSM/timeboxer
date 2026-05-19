import { useState, useEffect, useRef, useCallback } from 'react';
import { Play, Pause, X, Trophy } from 'lucide-react';

export default function Timer({ mode, duration, parentPIN, onComplete, onCancel }) {
  const [timeLeft, setTimeLeft] = useState(duration * 60);
  const [isActive, setIsActive] = useState(true);
  const [showWarning, setShowWarning] = useState(false);
  
  const [isOvertime, setIsOvertime] = useState(false);
  const [overtimeSeconds, setOvertimeSeconds] = useState(0);

  const isEarnMode = mode === 'earn';
  const targetEndAtRef = useRef(null);
  const overtimeStartAtRef = useRef(null);
  const warningSoundAtRef = useRef(0);
  const didRingAtTargetRef = useRef(false);

  const playToneSequence = useCallback((steps) => {
    try {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (!AudioContext) return;
      const ctx = new AudioContext();
      const master = ctx.createGain();
      master.gain.setValueAtTime(0.0001, ctx.currentTime);
      master.connect(ctx.destination);

      steps.forEach(({ frequency, start, duration: stepDuration }) => {
        const oscillator = ctx.createOscillator();
        const gain = ctx.createGain();
        oscillator.type = 'square';
        oscillator.frequency.setValueAtTime(frequency, ctx.currentTime + start);
        gain.gain.setValueAtTime(0.0001, ctx.currentTime + start);
        gain.gain.exponentialRampToValueAtTime(0.18, ctx.currentTime + start + 0.02);
        gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + start + stepDuration);
        oscillator.connect(gain);
        gain.connect(master);
        oscillator.start(ctx.currentTime + start);
        oscillator.stop(ctx.currentTime + start + stepDuration + 0.04);
      });

      const lastStep = steps.at(-1);
      const closeAfter = lastStep ? lastStep.start + lastStep.duration + 0.3 : 0.5;
      window.setTimeout(() => ctx.close().catch(() => {}), closeAfter * 1000);
    } catch {
      // Audio is best-effort; browsers may block it if the tab has no active user gesture.
    }
  }, []);

  const playCompletionBell = useCallback(() => {
    playToneSequence([
      { frequency: 784, start: 0, duration: 0.18 },
      { frequency: 988, start: 0.24, duration: 0.18 },
      { frequency: 1175, start: 0.48, duration: 0.3 },
    ]);
  }, [playToneSequence]);

  const playWarningAlarm = useCallback(() => {
    const now = Date.now();
    if (now - warningSoundAtRef.current < 1500) return;
    warningSoundAtRef.current = now;
    playToneSequence([
      { frequency: 220, start: 0, duration: 0.16 },
      { frequency: 220, start: 0.24, duration: 0.16 },
      { frequency: 220, start: 0.48, duration: 0.3 },
    ]);
  }, [playToneSequence]);

  const syncTimerFromClock = useCallback(() => {
    if (!targetEndAtRef.current) {
      targetEndAtRef.current = Date.now() + timeLeft * 1000;
    }

    if (isEarnMode && isOvertime) {
      if (!overtimeStartAtRef.current) overtimeStartAtRef.current = Date.now();
      setOvertimeSeconds(Math.max(0, Math.floor((Date.now() - overtimeStartAtRef.current) / 1000)));
      return;
    }

    const remaining = Math.max(0, Math.ceil((targetEndAtRef.current - Date.now()) / 1000));
    setTimeLeft(remaining);

    if (remaining === 0 && isEarnMode && !isOvertime) {
      if (!didRingAtTargetRef.current) {
        playCompletionBell();
        didRingAtTargetRef.current = true;
      }
      setIsOvertime(true);
      overtimeStartAtRef.current = Date.now();
    }
  }, [isEarnMode, isOvertime, playCompletionBell, timeLeft]);

  const freezeTimer = useCallback(() => {
    syncTimerFromClock();
    if (isEarnMode && isOvertime) {
      overtimeStartAtRef.current = null;
    } else {
      targetEndAtRef.current = null;
    }
  }, [isEarnMode, isOvertime, syncTimerFromClock]);

  const pauseForFocusBreak = useCallback(() => {
    if (!isEarnMode || isOvertime) return;
    freezeTimer();
    setIsActive(false);
    setShowWarning(true);
    playWarningAlarm();
  }, [freezeTimer, isEarnMode, isOvertime, playWarningAlarm]);

  // Security checks
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.hidden && isEarnMode && !isOvertime) {
        pauseForFocusBreak();
      }
    };

    const checkWindowSize = () => {
      if (isEarnMode && !isOvertime) {
        const isMaximized = 
          !!document.fullscreenElement ||
          (window.innerWidth >= window.screen.availWidth - 100 && 
           window.innerHeight >= window.screen.availHeight - 250);
          
        if (!isMaximized) {
          pauseForFocusBreak();
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('resize', checkWindowSize);
    
    checkWindowSize();

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('resize', checkWindowSize);
    };
  }, [isEarnMode, isOvertime, pauseForFocusBreak]);

  // Tick logic based on wall-clock time so display sleep/throttling does not lose time.
  useEffect(() => {
    let interval = null;
    if (isActive) {
      if (!targetEndAtRef.current) {
        targetEndAtRef.current = Date.now() + timeLeft * 1000;
      }
      if (isEarnMode && isOvertime && !overtimeStartAtRef.current) {
        overtimeStartAtRef.current = Date.now() - overtimeSeconds * 1000;
      }

      interval = setInterval(() => {
        if (isEarnMode) {
          if (!isOvertime) {
            syncTimerFromClock();
          } else {
            syncTimerFromClock();
          }
        } else {
          // Spend Mode
          const remaining = Math.max(0, Math.ceil((targetEndAtRef.current - Date.now()) / 1000));
          setTimeLeft(remaining);
          if (remaining === 0) {
            setIsActive(false);
            playCompletionBell();
            onComplete(duration, 0); 
          }
        }
      }, 1000);
      syncTimerFromClock();
    }
    return () => clearInterval(interval);
  }, [duration, isActive, isEarnMode, isOvertime, onComplete, overtimeSeconds, playCompletionBell, syncTimerFromClock, timeLeft]);

  // Request fullscreen wrapper
  const toggleTimer = async () => {
    if (!isActive) {
      if (isEarnMode && !isOvertime) {
        const isMaximized = 
          !!document.fullscreenElement ||
          (window.innerWidth >= window.screen.availWidth - 100 && 
           window.innerHeight >= window.screen.availHeight - 250);

        if (!isMaximized) {
          try {
            await document.documentElement.requestFullscreen();
          } catch {
            alert("⚠️ 必须将窗口最大化或全屏才能继续计时！");
            return;
          }
        }
      }
      setIsActive(true);
      if (showWarning) setShowWarning(false);
    } else {
      freezeTimer();
      setIsActive(false);
    }
  };

  const formatTime = (seconds) => {
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const handleActionClick = () => {
    if (isEarnMode) {
      if (isOvertime) {
        // Claim reward!
        const extraMinutes = Math.floor(overtimeSeconds / 60);
        onComplete(duration, extraMinutes);
      } else {
        const pin = window.prompt("放弃任务？提前退出收益为0！请输入密码以退出 (Parent PIN):");
        if (pin === parentPIN) {
          onCancel();
        } else if (pin !== null) {
          alert("密码错误 (Incorrect PIN)!");
        }
      }
    } else {
      // Spend mode early exit
      const pin = window.prompt("家长锁：请输入密码以提前退出娱乐 (Parent PIN):");
      if (pin === parentPIN) {
        const playedSeconds = (duration * 60) - timeLeft;
        const playedMinutes = Math.ceil(playedSeconds / 60); // Round up to nearest minute
        onCancel(playedMinutes);
      } else if (pin !== null) {
        alert("密码错误 (Incorrect PIN)!");
      }
    }
  };

  let titleColor = isEarnMode ? 'text-brand-green' : 'text-brand-red';
  let titleText = isEarnMode ? 'Earning Time...' : 'Spending Time...';
  let timeColor = isEarnMode ? 'text-brand-green' : 'text-brand-red';
  
  if (isOvertime) {
    titleColor = 'text-[#FFD700]';
    timeColor = 'text-[#FFD700]';
    titleText = 'OVERTIME BONUS!';
  }

  return (
    <div className="fixed inset-0 bg-black/90 z-50 flex flex-col items-center justify-center p-4">
      <div className={`text-2xl font-bold mb-8 uppercase tracking-widest ${titleColor} animate-pulse`}>
        {titleText}
      </div>
      
      <div className={`text-[120px] sm:text-[180px] leading-none font-mono font-bold tabular-nums tracking-tighter ${timeColor} drop-shadow-[0_0_30px_rgba(currentcolor,0.4)]`}>
        {isOvertime ? `+${formatTime(overtimeSeconds)}` : formatTime(timeLeft)}
      </div>

      <div className="mt-16 flex items-center gap-8">
        <button 
          onClick={toggleTimer}
          className="w-20 h-20 rounded-full bg-white/10 flex items-center justify-center hover:bg-white/20 transition-colors"
        >
          {isActive ? <Pause size={40} className="text-white" /> : <Play size={40} className="text-white ml-2" />}
        </button>
        
        <button 
          onClick={handleActionClick}
          className={`w-16 h-16 rounded-full flex items-center justify-center transition-colors shadow-lg ${
            isOvertime 
              ? 'bg-[#FFD700]/20 hover:bg-[#FFD700]/40 text-[#FFD700] border border-[#FFD700]/50' 
              : 'bg-red-500/20 hover:bg-red-500/40 text-red-500 border border-transparent'
          }`}
        >
          {isOvertime ? <Trophy size={32} /> : <X size={32} />}
        </button>
      </div>
      
      <div className="mt-8 text-white/50 text-sm h-8 text-center max-w-2xl px-4">
        {showWarning ? (
          <span className="text-red-500 font-bold animate-pulse text-lg">⚠️ 警告：检测到页面切换或窗口缩小，计时已暂停！</span>
        ) : isOvertime ? (
          <span className="text-[#FFD700]">Target Reached! Keep going to earn bonus time coins, or click the Trophy to claim.</span>
        ) : (
          <span>Stay focused. {isEarnMode && "Switching apps or shrinking the window will pause the timer."}</span>
        )}
      </div>
    </div>
  );
}
