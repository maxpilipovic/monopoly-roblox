// Synthesises the game's sound effects into one "sound sheet": assets/audio/sfx.wav, every sound
// one after another with silence between, and assets/audio/sfx.json mapping each name to its
// start and length (the game plays a slice with Sound.PlaybackRegion). One upload for them all.
// Everything is built from oscillators, filtered noise, bells and a small room reverb, in one key
// (C major), so the set sounds like it belongs together.
//
// Usage: node tools/audio/sfx.js
"use strict";
const fs = require("fs");
const path = require("path");

const SR = 44100;
const GAP = 0.35; // silence after each sound, so slices never bleed
const OUT = path.join(__dirname, "..", "..", "assets", "audio");

// Notes ------------------------------------------------------------------------------------------
const NOTE = (name) => {
	const m = /^([A-G])(#|b)?(\d)$/.exec(name);
	const semis = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0);
	return 440 * Math.pow(2, (semis + (Number(m[3]) - 4) * 12 - 9) / 12);
};

// A deterministic random, so every render is identical.
let seed = 1234567;
const rand = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296);

// Buffers and building blocks ------------------------------------------------------------------
const make = (seconds) => new Float32Array(Math.ceil(seconds * SR));

function mixInto(dst, src, at, gain = 1) {
	const o = Math.floor(at * SR);
	for (let i = 0; i < src.length && o + i < dst.length; i++) dst[o + i] += src[i] * gain;
}

// Exponential decay envelope with a short linear attack.
const env = (t, attack, decay) => (t < attack ? t / attack : Math.exp(-(t - attack) / decay));

// A tone: `freq(t)` in Hz, waveform "sine" | "tri" | "saw" | "square" (soft, few harmonics).
function tone(seconds, freq, { wave = "sine", attack = 0.004, decay = 0.3, gain = 1, vibrato = 0, vibRate = 5.5 } = {}) {
	const b = make(seconds);
	let phase = 0;
	for (let i = 0; i < b.length; i++) {
		const t = i / SR;
		const f = (typeof freq === "function" ? freq(t) : freq) * (1 + vibrato * Math.sin(2 * Math.PI * vibRate * t));
		phase += (2 * Math.PI * f) / SR;
		let s;
		if (wave === "sine") s = Math.sin(phase);
		else if (wave === "tri") s = (2 / Math.PI) * Math.asin(Math.sin(phase));
		else {
			// Band-limited by hand: a few odd (square) or all (saw) harmonics, rolled off.
			s = 0;
			const n = Math.max(1, Math.min(12, Math.floor(9000 / f)));
			for (let k = 1; k <= n; k++) {
				if (wave === "square" && k % 2 === 0) continue;
				s += Math.sin(phase * k) / k;
			}
			s *= wave === "square" ? 0.8 : 0.6;
		}
		b[i] = s * env(t, attack, decay) * gain;
	}
	return b;
}

// Biquad filter (RBJ cookbook), applied in place.
function biquad(b, type, f0, q = 0.707) {
	const w = (2 * Math.PI * f0) / SR;
	const cos = Math.cos(w), alpha = Math.sin(w) / (2 * q);
	let b0, b1, b2, a0, a1, a2;
	if (type === "low") { b0 = (1 - cos) / 2; b1 = 1 - cos; b2 = b0; a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha; }
	else if (type === "high") { b0 = (1 + cos) / 2; b1 = -(1 + cos); b2 = b0; a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha; }
	else { b0 = alpha; b1 = 0; b2 = -alpha; a0 = 1 + alpha; a1 = -2 * cos; a2 = 1 - alpha; } // band
	let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
	for (let i = 0; i < b.length; i++) {
		const x = b[i];
		const y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0;
		x2 = x1; x1 = x; y2 = y1; y1 = y;
		b[i] = y;
	}
	return b;
}

// Noise shaped by an envelope, then filtered. `sweep(t)` (optional) moves a band-pass centre.
function noise(seconds, { attack = 0.002, decay = 0.05, gain = 1, type = "band", freq = 2000, q = 1, sweep = null } = {}) {
	const b = make(seconds);
	for (let i = 0; i < b.length; i++) b[i] = (rand() * 2 - 1) * env(i / SR, attack, decay) * gain;
	if (!sweep) return biquad(b, type, freq, q);
	// A moving band-pass, filtered in short blocks.
	const out = make(seconds);
	const block = 256;
	let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
	for (let s = 0; s < b.length; s += block) {
		const f0 = sweep(s / SR);
		const w = (2 * Math.PI * f0) / SR, cos = Math.cos(w), alpha = Math.sin(w) / (2 * q);
		const a0 = 1 + alpha, a1 = -2 * cos, a2 = 1 - alpha;
		for (let i = s; i < Math.min(s + block, b.length); i++) {
			const x = b[i];
			const y = (alpha * x - alpha * x2 - a1 * y1 - a2 * y2) / a0;
			x2 = x1; x1 = x; y2 = y1; y1 = y;
			out[i] = y;
		}
	}
	return out;
}

// A struck bell: inharmonic partials with their own decays (bright, glassy, metallic).
function bell(seconds, f, { decay = 0.9, gain = 1, bright = 1 } = {}) {
	const partials = [[1, 1, 1], [2.0, 0.55, 0.7], [2.76, 0.4 * bright, 0.5], [4.07, 0.25 * bright, 0.35], [5.43, 0.12 * bright, 0.25]];
	const b = make(seconds);
	for (const [ratio, amp, life] of partials) mixInto(b, tone(seconds, f * ratio, { decay: decay * life, attack: 0.002 }), 0, amp * gain);
	return b;
}

// A marimba-ish mallet: fundamental plus its 4th partial, quick decay. Warm and woody.
function mallet(seconds, f, { decay = 0.25, gain = 1 } = {}) {
	const b = tone(seconds, f, { decay, attack: 0.002, gain });
	mixInto(b, tone(seconds, f * 3.93, { decay: decay * 0.25, attack: 0.001 }), 0, 0.35 * gain);
	mixInto(b, noise(0.02, { decay: 0.004, freq: f * 6, q: 2 }), 0, 0.3 * gain);
	return b;
}

// A coin: a bright metallic ping (two close inharmonic partials beat against each other).
function coin(seconds, f, gain = 1) {
	const b = make(seconds);
	for (const [ratio, amp, d] of [[1, 1, 0.22], [1.0135, 0.8, 0.2], [2.41, 0.45, 0.12], [3.89, 0.25, 0.07]]) {
		mixInto(b, tone(seconds, f * ratio, { decay: d, attack: 0.001 }), 0, amp * gain);
	}
	mixInto(b, noise(0.03, { decay: 0.005, type: "high", freq: 5000 }), 0, 0.5 * gain);
	return b;
}

// A wooden knock: a pitched thump with a short click.
function knock(seconds, f, gain = 1) {
	const b = tone(seconds, (t) => f * (1 + 0.6 * Math.exp(-t / 0.01)), { decay: 0.045, attack: 0.0008, gain });
	mixInto(b, noise(0.05, { decay: 0.012, freq: f * 3, q: 1.5 }), 0, 0.7 * gain);
	return b;
}

// A soft room: four combs and two all-passes (Schroeder), mixed in lightly.
function reverb(b, wet = 0.18, room = 0.78) {
	const tail = make(b.length / SR + 1.2);
	const combs = [1557, 1617, 1491, 1422].map((n) => ({ buf: new Float32Array(n), i: 0, store: 0 }));
	const passes = [225, 556].map((n) => ({ buf: new Float32Array(n), i: 0 }));
	for (let n = 0; n < tail.length; n++) {
		const x = n < b.length ? b[n] : 0;
		let s = 0;
		for (const c of combs) {
			const y = c.buf[c.i];
			c.store = y * 0.8 + c.store * 0.2;
			c.buf[c.i] = x + c.store * room;
			c.i = (c.i + 1) % c.buf.length;
			s += y;
		}
		s *= 0.25;
		for (const a of passes) {
			const y = a.buf[a.i];
			a.buf[a.i] = s + y * 0.5;
			a.i = (a.i + 1) % a.buf.length;
			s = y - s * 0.5;
		}
		tail[n] = (n < b.length ? b[n] : 0) + s * wet;
	}
	return tail;
}

// Trims trailing silence, fades the end, and normalises the peak to `peak`.
function finish(b, peak = 0.8) {
	let end = b.length;
	while (end > 0 && Math.abs(b[end - 1]) < 0.0008) end--;
	const out = b.slice(0, Math.max(end, 1));
	const fade = Math.min(Math.floor(0.03 * SR), out.length);
	for (let i = 0; i < fade; i++) out[out.length - 1 - i] *= i / fade;
	let max = 0;
	for (const v of out) max = Math.max(max, Math.abs(v));
	if (max > 0) for (let i = 0; i < out.length; i++) out[i] *= peak / max;
	return out;
}

// Plays notes in sequence: [[note, at, voice, gain?], ...] into a buffer.
function phrase(seconds, notes) {
	const b = make(seconds);
	for (const [note, at, voice, gain = 1] of notes) mixInto(b, voice(NOTE(note)), at, gain);
	return b;
}

// The sounds ----------------------------------------------------------------------------------------
const SOUNDS = {
	// Interface
	Click: () => finish(reverb(knock(0.12, 1400, 1), 0.08), 0.55),
	Hover: () => finish(tone(0.06, 2600, { decay: 0.012, attack: 0.001 }), 0.18),
	Open: () => {
		const b = noise(0.32, { attack: 0.08, decay: 0.08, sweep: (t) => 400 + t * 9000, q: 1.2, gain: 0.7 });
		mixInto(b, mallet(0.4, NOTE("G5"), { decay: 0.12 }), 0.1, 0.5);
		return finish(reverb(b, 0.15), 0.5);
	},
	Close: () => finish(reverb(noise(0.25, { attack: 0.03, decay: 0.06, sweep: (t) => 3800 - t * 11000, q: 1.2 }), 0.12), 0.4),
	Tab: () => finish(mallet(0.15, NOTE("E6"), { decay: 0.05 }), 0.4),
	Error: () => finish(phrase(0.5, [["E3", 0, (f) => tone(0.2, f, { wave: "square", decay: 0.07 })], ["C3", 0.12, (f) => tone(0.3, f, { wave: "square", decay: 0.1 })]]).map((v) => v), 0.45),
	Notify: () => finish(reverb(phrase(0.8, [["E5", 0, (f) => mallet(0.6, f)], ["A5", 0.11, (f) => mallet(0.7, f)]]), 0.2), 0.6),

	// The board
	Hop: () => finish(knock(0.12, 520, 1), 0.6),
	YourTurn: () => finish(reverb(phrase(1.4, [["C6", 0, (f) => bell(1.2, f, { decay: 0.6 })], ["E6", 0.09, (f) => bell(1.2, f, { decay: 0.6 })], ["G6", 0.18, (f) => bell(1.2, f, { decay: 0.8 })]]), 0.25), 0.6),
	Doubles: () => finish(reverb(phrase(1.0, [["G6", 0, (f) => bell(0.9, f, { decay: 0.4 })], ["G6", 0.13, (f) => bell(0.9, f, { decay: 0.5 })], ["D7", 0.26, (f) => bell(0.9, f, { decay: 0.6, bright: 0.6 }), 0.7]]), 0.2), 0.6),
	PassGo: () => {
		// "Cha-ching": a drawer clunk, then two register bells.
		const b = make(1.4);
		mixInto(b, knock(0.15, 180, 1), 0, 0.9);
		mixInto(b, noise(0.12, { decay: 0.03, freq: 3500, q: 0.8 }), 0, 0.4);
		mixInto(b, bell(1.2, NOTE("E6"), { decay: 0.5, bright: 1.3 }), 0.09, 0.8);
		mixInto(b, bell(1.2, NOTE("A6"), { decay: 0.7, bright: 1.3 }), 0.2, 0.9);
		return finish(reverb(b, 0.2), 0.7);
	},
	Buy: () => {
		// A stamp, then a bright confirming ding.
		const b = make(1.1);
		mixInto(b, knock(0.12, 140, 1), 0, 1);
		mixInto(b, noise(0.1, { decay: 0.02, freq: 1200, q: 0.7 }), 0, 0.5);
		mixInto(b, phrase(1.0, [["C6", 0, (f) => bell(0.9, f, { decay: 0.4 })], ["G6", 0.08, (f) => bell(0.9, f, { decay: 0.6 })]]), 0.07, 0.7);
		return finish(reverb(b, 0.18), 0.7);
	},
	Coin: () => finish(reverb(coin(0.5, 2100), 0.15), 0.6),
	Coins: () => {
		const b = make(1.0);
		for (let k = 0; k < 7; k++) mixInto(b, coin(0.5, 1700 + rand() * 1400, 0.8 - k * 0.07), k * 0.055 + rand() * 0.02);
		return finish(reverb(b, 0.18), 0.65);
	},
	Pay: () => {
		const b = make(0.9);
		mixInto(b, coin(0.5, 2300), 0, 0.7);
		mixInto(b, coin(0.5, 1800), 0.09, 0.6);
		mixInto(b, coin(0.5, 1400), 0.18, 0.5);
		mixInto(b, knock(0.12, 220), 0.24, 0.5);
		return finish(reverb(b, 0.15), 0.6);
	},
	Card: () => {
		const b = noise(0.25, { attack: 0.005, decay: 0.05, sweep: (t) => 1500 + t * 14000, q: 0.9 });
		mixInto(b, noise(0.06, { decay: 0.01, freq: 3000, q: 1 }), 0.11, 0.6);
		return finish(reverb(b, 0.08), 0.55);
	},
	Build: () => finish(reverb(phrase(0.6, [["A3", 0, (f) => knock(0.15, f * 2), 1], ["A3", 0.16, (f) => knock(0.15, f * 2.1), 0.9]]), 0.15), 0.65),
	Hotel: () => {
		const b = make(1.3);
		mixInto(b, knock(0.15, 260), 0, 1);
		mixInto(b, knock(0.15, 280), 0.14, 0.9);
		mixInto(b, phrase(1.2, [["C6", 0, (f) => bell(1, f)], ["E6", 0.06, (f) => bell(1, f)], ["G6", 0.12, (f) => bell(1, f)]]), 0.28, 0.6);
		return finish(reverb(b, 0.2), 0.7);
	},
	Mortgage: () => {
		const b = knock(0.2, 110, 1);
		mixInto(b, noise(0.2, { decay: 0.04, freq: 2500, q: 0.6 }), 0.01, 0.5);
		return finish(reverb(b, 0.12), 0.6);
	},
	TradeDone: () => finish(reverb(phrase(1.3, [["C5", 0, (f) => mallet(1, f, { decay: 0.4 })], ["E5", 0.08, (f) => mallet(1, f, { decay: 0.4 })], ["G5", 0.16, (f) => mallet(1, f, { decay: 0.45 })], ["C6", 0.24, (f) => bell(1.1, f, { decay: 0.6 }), 0.7]]), 0.2), 0.65),
	Bankrupt: () => {
		// A muted trombone sliding down: wah, wah, wah, waaah.
		const voice = (f, len) => biquad(tone(len, (t) => f * (1 - 0.025 * Math.min(t / len, 1)), { wave: "saw", attack: 0.03, decay: len * 0.7, vibrato: 0.006 }), "low", 1100, 0.9);
		const b = make(2.6);
		mixInto(b, voice(NOTE("D4"), 0.42), 0, 0.8);
		mixInto(b, voice(NOTE("C#4"), 0.42), 0.45, 0.8);
		mixInto(b, voice(NOTE("C4"), 0.42), 0.9, 0.8);
		mixInto(b, biquad(tone(1.3, (t) => NOTE("B3") * (1 - 0.04 * Math.min(t, 1)), { wave: "saw", attack: 0.04, decay: 0.9, vibrato: 0.018, vibRate: 5 }), "low", 1000, 0.9), 1.35, 0.85);
		return finish(reverb(b, 0.15), 0.6);
	},
	Win: () => {
		// A brass fanfare: a rising arpeggio, then the full chord, with sparkles on top.
		const brass = (f, len) => biquad(tone(len, f, { wave: "saw", attack: 0.02, decay: len * 0.8, vibrato: 0.004 }), "low", 2600, 0.8);
		const b = make(2.8);
		[["C5", 0], ["E5", 0.13], ["G5", 0.26]].forEach(([n, at]) => mixInto(b, brass(NOTE(n), 0.22), at, 0.6));
		for (const n of ["C5", "E5", "G5", "C6"]) mixInto(b, brass(NOTE(n), 1.6), 0.42, 0.42);
		for (let k = 0; k < 8; k++) mixInto(b, bell(0.8, NOTE("C7") * (1 + rand() * 0.6), { decay: 0.25, gain: 0.5 }), 0.45 + k * 0.11, 0.35);
		return finish(reverb(b, 0.25), 0.75);
	},
	Lose: () => finish(reverb(phrase(1.6, [["G4", 0, (f) => mallet(0.8, f, { decay: 0.5 })], ["Eb4", 0.22, (f) => mallet(0.8, f, { decay: 0.5 })], ["C4", 0.44, (f) => mallet(1.2, f, { decay: 0.8 })]]), 0.25), 0.6),
	Tick: () => finish(knock(0.08, 2400, 1), 0.4),
	SpinTick: () => finish(knock(0.06, 3000, 1), 0.35),
	SpinDing: () => finish(reverb(bell(1.2, NOTE("C6"), { decay: 0.7 }), 0.2), 0.6),

	// Chests and rewards
	ChestShake: () => {
		const b = make(0.5);
		for (let k = 0; k < 6; k++) mixInto(b, knock(0.1, 300 + rand() * 250, 0.7 + rand() * 0.3), k * 0.075 + rand() * 0.015);
		return finish(b, 0.55);
	},
	ChestOpen: () => {
		const b = make(2.2);
		mixInto(b, biquad(noise(0.6, { attack: 0.002, decay: 0.18, type: "low", freq: 600 }), "low", 400), 0, 1);
		mixInto(b, tone(0.6, (t) => 90 * Math.exp(-t * 2), { decay: 0.25 }), 0, 0.9);
		for (let k = 0; k < 10; k++) mixInto(b, bell(1.0, NOTE("C6") * Math.pow(2, Math.floor(rand() * 8) / 6), { decay: 0.4, gain: 0.5 }), 0.05 + k * 0.07, 0.4);
		return finish(reverb(b, 0.28), 0.75);
	},
	RevealCommon: () => finish(reverb(phrase(1.0, [["E6", 0, (f) => bell(0.9, f, { decay: 0.5 })], ["G6", 0.1, (f) => bell(0.9, f, { decay: 0.6 })]]), 0.2), 0.55),
	RevealRare: () => finish(reverb(phrase(1.3, [["C6", 0, (f) => bell(1, f)], ["E6", 0.09, (f) => bell(1, f)], ["G6", 0.18, (f) => bell(1, f)], ["C7", 0.27, (f) => bell(1.1, f, { decay: 0.8 }), 0.7]]), 0.25), 0.6),
	RevealEpic: () => {
		const b = phrase(1.8, [["C6", 0, (f) => bell(1, f)], ["E6", 0.08, (f) => bell(1, f)], ["G6", 0.16, (f) => bell(1, f)], ["B6", 0.24, (f) => bell(1, f)], ["D7", 0.32, (f) => bell(1.4, f, { decay: 1.0 }), 0.8]]);
		mixInto(b, noise(1.2, { attack: 0.3, decay: 0.4, sweep: (t) => 3000 + t * 5000, q: 2, gain: 0.25 }), 0.2);
		return finish(reverb(b, 0.3), 0.65);
	},
	RevealLegendary: () => {
		const brass = (f, len) => biquad(tone(len, f, { wave: "saw", attack: 0.03, decay: len * 0.9, vibrato: 0.005 }), "low", 3000, 0.8);
		const b = make(3.4);
		mixInto(b, noise(0.9, { attack: 0.5, decay: 0.15, sweep: (t) => 300 + t * 8000, q: 1.4, gain: 0.5 }), 0);
		for (const n of ["C4", "G4", "C5", "E5", "G5"]) mixInto(b, brass(NOTE(n), 2.2), 0.55, 0.35);
		for (let k = 0; k < 14; k++) mixInto(b, bell(1.0, NOTE("C7") * Math.pow(2, Math.floor(rand() * 10) / 5), { decay: 0.35, gain: 0.5 }), 0.55 + k * 0.09, 0.35);
		return finish(reverb(b, 0.32), 0.8);
	},
	Claim: () => {
		const b = make(1.4);
		for (let k = 0; k < 5; k++) mixInto(b, coin(0.5, 1900 + k * 180, 0.7), k * 0.06);
		mixInto(b, phrase(1.1, [["G5", 0, (f) => mallet(0.8, f)], ["C6", 0.1, (f) => mallet(0.8, f)], ["E6", 0.2, (f) => bell(1, f, { decay: 0.6 }), 0.7]]), 0.28, 0.8);
		return finish(reverb(b, 0.22), 0.7);
	},
	Equip: () => {
		const b = noise(0.3, { attack: 0.01, decay: 0.07, sweep: (t) => 2000 + t * 12000, q: 2.5, gain: 0.6 });
		mixInto(b, bell(0.6, NOTE("A6"), { decay: 0.25, bright: 1.4 }), 0.05, 0.6);
		return finish(reverb(b, 0.15), 0.55);
	},
}

// Render ------------------------------------------------------------------------------------------
function wav16(samples) {
	const data = Buffer.alloc(samples.length * 2);
	for (let i = 0; i < samples.length; i++) data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i])) * 32767), i * 2);
	const header = Buffer.alloc(44);
	header.write("RIFF", 0); header.writeUInt32LE(36 + data.length, 4); header.write("WAVE", 8);
	header.write("fmt ", 12); header.writeUInt32LE(16, 16); header.writeUInt16LE(1, 20); header.writeUInt16LE(1, 22);
	header.writeUInt32LE(SR, 24); header.writeUInt32LE(SR * 2, 28); header.writeUInt16LE(2, 32); header.writeUInt16LE(16, 34);
	header.write("data", 36); header.writeUInt32LE(data.length, 40);
	return Buffer.concat([header, data]);
}

const parts = [];
const map = {};
let cursor = 0.1;
for (const [name, build] of Object.entries(SOUNDS)) {
	const s = build();
	map[name] = { start: Number(cursor.toFixed(4)), length: Number((s.length / SR).toFixed(4)) };
	parts.push({ at: cursor, s });
	cursor += s.length / SR + GAP;
}
const sheet = make(cursor);
for (const { at, s } of parts) mixInto(sheet, s, at);
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, "sfx.wav"), wav16(sheet));
fs.writeFileSync(path.join(OUT, "sfx.json"), JSON.stringify(map, null, "\t") + "\n");
console.log(`${Object.keys(map).length} sounds, ${cursor.toFixed(1)} s`);
for (const [n, r] of Object.entries(map)) console.log(n.padEnd(16), r.start.toFixed(2), r.length.toFixed(2));

// The game's copy of the map.
const luau = Object.entries(map).map(([k, v]) => `\t${k} = { ${v.start}, ${v.length} },`);
fs.writeFileSync(
	path.join(__dirname, "..", "..", "src", "client", "SoundSheet.luau"),
	`--!strict\n-- Generated by tools/audio/sfx.js from assets/audio/sfx.json. Do not edit.\n-- Where each synthesised sound sits in the uploaded sheet: { start seconds, length seconds }.\n\nreturn table.freeze({\n${luau.join("\n")}\n}) :: { [string]: { number } }\n`
);
