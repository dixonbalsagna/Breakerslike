// Fighter definitions and fighter construction: the prototype's ROSTER, mkF (here createFighter) and opp.

// Frozen so the roster can never become shared mutable state; createFighter copies every field into the fighter.
export const ROSTER = Object.freeze([
  Object.freeze({name:'KAI',  title:'Meridian Warden',    role:'hero',    col:'#3d8fdc', aura:'#8fd6ff', hair:'#22c7a9', care:1.0,  dmgMul:1.00, spd:1.00, maxhp:1600, sigName:'Meridian Lance'}),
  Object.freeze({name:'VORR', title:'Calamity Sovereign', role:'villain', col:'#a52a2a', aura:'#ff5a3c', hair:'#181818', care:-0.8, dmgMul:1.0, spd:0.95, maxhp:1600, sigName:'Calamity Wave'})
]);

// mkF with the same fields, order and initial values, minus stanceOk (written every tick, never read) and plus an
// explicit dPrev: null (the prototype leaves it undefined until the first attack; both are falsy).
export function createFighter(def, x, keys, ai){
  return {name:def.name,title:def.title,role:def.role,col:def.col,aura:def.aura,hair:def.hair,care:def.care,dmgMul:def.dmgMul,spd:def.spd,maxhp:def.maxhp,sigName:def.sigName,
    hp:def.maxhp,x,y:90,vx:0,vy:0,face:1,ki:60,power:0,tier:1,stance:0,state:'free',stateT:0,hidden:false,hideT:0,hiddenFor:0,menace:0,anguish:0,ambush:false,
    rush:null,rot:0,spin:0,bounces:0,launchBy:null,lastAtkT:-99,hurtT:-99,keys,ai:ai?{t:0.5,atk:1.2,sT:0,sOff:0}:null,beamCharge:null,wet:false,lastSeen:null,ambushUntil:0,
    in:{mx:0,my:0,dash:false,charge:false,light:false,heavy:false,sig:false,stance:-1},
    dPrev:null};
}

// The other fighter. Anything that is not fighters[0] gets fighters[0], as in the prototype.
export function opp(S, f){ return S.fighters[0] === f ? S.fighters[1] : S.fighters[0]; }
