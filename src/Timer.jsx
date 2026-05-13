import { useState, useEffect } from 'react';
import { Play, Pause, X, Trophy } from 'lucide-react';

export default function Timer({ mode, duration, parentPIN, onComplete, onCancel }) {
  const [timeLeft, setTimeLeft] = useState(duration * 60);
  const [isActive, setIsActive] = useState(true);
  const [showWarning, setShowWarning] = useState(false);
  
  const [isOvertime, setIsOvertime] = useState(false);
  const [overtimeSeconds, setOvertimeSeconds] = useState(0);

  const isEarnMode = mode === 'earn';

  // Security checks
  useEffect(() => {
    const handleVisibilityChange = () => {
      if (document.hidden && isEarnMode && !isOvertime) {
        setIsActive(false);
        setShowWarning(true);
      }
    };

    const handleBlur = () => {
      if (isEarnMode && !isOvertime) {
        setIsActive(false);
        setShowWarning(true);
      }
    };

    const checkWindowSize = () => {
      if (isEarnMode && !isOvertime) {
        const isMaximized = 
          !!document.fullscreenElement ||
          (window.innerWidth >= window.screen.availWidth - 100 && 
           window.innerHeight >= window.screen.availHeight - 250);
          
        if (!isMaximized) {
          setIsActive(false);
          setShowWarning(true);
        }
      }
    };

    document.addEventListener('visibilitychange', handleVisibilityChange);
    window.addEventListener('blur', handleBlur);
    window.addEventListener('resize', checkWindowSize);
    
    checkWindowSize();

    return () => {
      document.removeEventListener('visibilitychange', handleVisibilityChange);
      window.removeEventListener('blur', handleBlur);
      window.removeEventListener('resize', checkWindowSize);
    };
  }, [isEarnMode, isOvertime]);

  // Tick logic
  useEffect(() => {
    let interval = null;
    if (isActive) {
      interval = setInterval(() => {
        if (isEarnMode) {
          if (!isOvertime) {
            setTimeLeft((prev) => {
              if (prev <= 1) {
                new Audio('https://assets.mixkit.co/active_storage/sfx/2013/2013-preview.mp3').play().catch(()=>{});
                setIsOvertime(true);
                return 0;
              }
              return prev - 1;
            });
          } else {
            setOvertimeSeconds((prev) => prev + 1);
          }
        } else {
          // Spend Mode
          setTimeLeft((prev) => {
            if (prev <= 1) {
              setIsActive(false);
              onComplete(duration, 0); 
              return 0;
            }
            return prev - 1;
          });
        }
      }, 1000);
    }
    return () => clearInterval(interval);
  }, [isActive, isOvertime, isEarnMode, duration, onComplete]);

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
          } catch (err) {
            alert("⚠️ 必须将窗口最大化或全屏才能继续计时！");
            return;
          }
        }
      }
      setIsActive(true);
      if (showWarning) setShowWarning(false);
    } else {
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
