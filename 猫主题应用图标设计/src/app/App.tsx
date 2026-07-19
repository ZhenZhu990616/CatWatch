import React from 'react';

export default function App() {
  return (
    <div className="size-full flex items-center justify-center bg-gray-50">
      <div className="flex flex-col items-center gap-12">
        
        {/* Header/Title */}
        <div className="text-center space-y-3">
          <h1 className="text-3xl font-black tracking-widest text-black uppercase">
            Feline Minimal
          </h1>
          <p className="text-gray-500 text-sm tracking-widest font-medium">
            极简黑白 · 单一特征提取设计
          </p>
        </div>

        {/* 主展示图标 - 提取【猫耳与头部轮廓】 (负空间极简设计) */}
        <div className="w-72 h-72 bg-black rounded-[3rem] shadow-2xl shadow-black/20 flex items-center justify-center overflow-hidden relative group transition-transform duration-500 hover:scale-105">
          <svg
            viewBox="0 0 100 100"
            className="w-full h-full"
            fill="none"
            xmlns="http://www.w3.org/2000/svg"
          >
            {/* 负空间白猫探头 */}
            <path 
              d="M 15 105 
                 L 20 35 
                 L 38 60 
                 Q 50 52 62 60 
                 L 80 35 
                 L 85 105 Z" 
              fill="white" 
            />
          </svg>
        </div>

        {/* 图标变体展示 */}
        <div className="flex gap-8 mt-4">
          
          {/* 变体 1：提取【猫爪】 - 纯粹的几何圆与柔和弧线 */}
          <div className="w-24 h-24 bg-white rounded-2xl shadow-xl shadow-black/5 hover:shadow-black/10 transition-all flex items-center justify-center p-4 group">
            <svg viewBox="0 0 100 100" className="w-full h-full transform transition-transform group-hover:scale-110" fill="none" xmlns="http://www.w3.org/2000/svg">
              {/* 肉球脚趾 */}
              <circle cx="25" cy="38" r="9" fill="black" />
              <circle cx="40" cy="20" r="10" fill="black" />
              <circle cx="60" cy="20" r="10" fill="black" />
              <circle cx="75" cy="38" r="9" fill="black" />
              {/* 主肉垫 */}
              <path 
                d="M 28 62 
                   C 28 50, 40 50, 50 57 
                   C 60 50, 72 50, 72 62 
                   C 78 79, 50 90, 50 90 
                   C 50 90, 22 79, 28 62 Z" 
                fill="black" 
              />
            </svg>
          </div>

          {/* 变体 2：提取【猫眼】 - 锐利的杏眼与深邃的竖瞳 */}
          <div className="w-24 h-24 bg-black rounded-full shadow-xl shadow-black/20 hover:shadow-black/30 transition-all flex items-center justify-center p-4 group">
            <svg viewBox="0 0 100 100" className="w-full h-full transform transition-transform group-hover:scale-110" fill="none" xmlns="http://www.w3.org/2000/svg">
              {/* 外眼眶 */}
              <path 
                d="M 10 50 C 35 25, 65 25, 90 50 C 65 75, 35 75, 10 50 Z" 
                fill="white" 
              />
              {/* 竖瞳 */}
              <path 
                d="M 50 30 C 58 40 58 60 50 70 C 42 60 42 40 50 30 Z" 
                fill="black" 
              />
            </svg>
          </div>

          {/* 变体 3：提取【胡须与鼻尖】 - 极致抽象的点线结合 */}
          <div className="w-24 h-24 bg-white rounded-2xl shadow-xl shadow-black/5 hover:shadow-black/10 transition-all border-[3px] border-black flex items-center justify-center p-4 group">
            <svg viewBox="0 0 100 100" className="w-full h-full transform transition-transform group-hover:scale-110" fill="none" xmlns="http://www.w3.org/2000/svg">
              {/* 小巧的鼻子 */}
              <path d="M 42 45 L 58 45 L 50 53 Z" fill="black" />
              {/* 左侧胡须 */}
              <line x1="10" y1="42" x2="35" y2="47" stroke="black" strokeWidth="4" strokeLinecap="round" />
              <line x1="14" y1="58" x2="35" y2="53" stroke="black" strokeWidth="4" strokeLinecap="round" />
              {/* 右侧胡须 */}
              <line x1="90" y1="42" x2="65" y2="47" stroke="black" strokeWidth="4" strokeLinecap="round" />
              <line x1="86" y1="58" x2="65" y2="53" stroke="black" strokeWidth="4" strokeLinecap="round" />
            </svg>
          </div>

        </div>

      </div>
    </div>
  );
}