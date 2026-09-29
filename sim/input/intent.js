// Player intent, the per-tick input record a fighter acts on: the prototype's f.in and the reset at the top of its control().
// Field order is the prototype's (mkF's `in` literal).
export function createIntent(){ return {mx:0, my:0, dash:false, charge:false, light:false, heavy:false, sig:false, stance:-1}; }

// Neutral input, exactly as control() cleared it every tick.
export function clearIntent(i){
  i.mx = i.my = 0; i.dash = i.charge = i.light = i.heavy = i.sig = false; i.stance = -1;
}

// Overwrite all eight fields of dst from src, as humanInput overwrote f.in for a human fighter. src must be a complete intent.
export function applyIntent(dst, src){
  dst.mx = src.mx; dst.my = src.my; dst.dash = src.dash; dst.charge = src.charge;
  dst.light = src.light; dst.heavy = src.heavy; dst.sig = src.sig; dst.stance = src.stance;
}
