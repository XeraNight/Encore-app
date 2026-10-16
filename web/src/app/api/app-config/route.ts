import { NextResponse } from 'next/server';


// Táto konfigurácia umožňuje na diaľku ovládať Encore iOS appku
// bez nutnosti čakať na schvaľovanie novej verzie v App Store.
export async function GET() {
  const config = {
    // Minimálna podporovaná verzia aplikácie (ak je na App Store kritický fix)
    min_version: '1.0.0',
    current_version: '1.0.0',

    // Núdzový režim údržby (napr. pri migrácii databázy)
    maintenance_mode: false,
    maintenance_message: 'Prebieha plánovaná údržba serverov. Vaše lokálne videá a metronóm fungujú offline.',

    // Feature Flags (Kill-switche pre jednotlivé funkcie)
    features: {
      canvas_realtime: true,
      cloud_sync: true,
      posture_analysis: true,
      ghost_overlay: true,
      dual_video_comparison: true,
      dance_metronome: true,
      in_app_feedback: true,
    },

    // Globálny oznam pre používateľov (napr. "Pripravujeme novú funkciu")
    announcement: null as string | null,

    // App Store URL pre rýchlu aktualizáciu
    app_store_url: 'https://apps.apple.com/app/encore-dance/id0000000000',
  };

  return NextResponse.json(config, {
    headers: {
      // Krátka cache (60 sekúnd), aby sa zmena kill-switchu prejavila rýchlo
      'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
    },
  });
}
