import './index.css';

import { context, requestExpandedMode } from '@devvit/web/client';
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

export const Splash = () => {
  const name = context.username;

  return (
    <div className="relative flex min-h-screen flex-col items-center justify-center gap-7 bg-[#14110d] px-6 text-[#d9cdb8]">
      <div className="flex flex-col items-center">
        <div className="text-[15px] font-semibold tracking-[0.42em] text-[#e7dcc6] uppercase">
          Tome
        </div>
        <div className="mt-1 h-px w-11 bg-[#6b5f49]" />
        <div className="mt-1 text-[10px] tracking-[0.5em] text-[#9c8f76] uppercase">
          Martial Arts
        </div>
      </div>

      <p className="max-w-xs text-center text-[13px] leading-relaxed text-[#9c8f76]">
        A build-and-discovery roguelike. Arrange your Tome, train to evolve your
        techniques, and fight your lineage forward.
      </p>

      <button
        className="cursor-pointer rounded-full bg-[#a8482f] px-6 py-2.5 text-[13px] font-semibold tracking-[0.14em] text-[#f2e9d8] uppercase transition-colors hover:bg-[#bb502f]"
        onClick={(e) => requestExpandedMode(e.nativeEvent, 'game')}
      >
        Enter the Hall
      </button>

      {name ? (
        <div className="absolute bottom-5 text-[11px] tracking-[0.2em] text-[#6b5f49] uppercase">
          {name}
        </div>
      ) : null}
    </div>
  );
};

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Splash />
  </StrictMode>
);
