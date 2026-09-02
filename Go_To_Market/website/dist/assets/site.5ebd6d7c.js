(function () {
'use strict';
var toggle = document.querySelector('.nav-toggle');
var nav = document.querySelector('.nav');
if (toggle && nav) {
toggle.addEventListener('click', function () {
var open = nav.classList.toggle('open');
toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
});
nav.addEventListener('click', function (event) {
if (event.target.tagName === 'A') { nav.classList.remove('open'); toggle.setAttribute('aria-expanded', 'false'); }
});
}
var page = document.querySelector('.hero-page');
if (!page) { return; }
var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
if (reduce) { page.classList.add('static'); return; }
var writeEnd = parseFloat(page.getAttribute('data-write-end') || '8');
var landDelay = 0.2;
var writeDelay = 1.3;
var settleHold = 3.2;
var timers = [];
function later(fn, seconds) { timers.push(window.setTimeout(fn, seconds * 1000)); }
function cycle() {
page.classList.remove('landing', 'writing', 'settled');
void page.getBoundingClientRect();
later(function () { page.classList.add('landing'); }, landDelay);
later(function () { page.classList.add('writing'); }, writeDelay);
later(function () { page.classList.add('settled'); }, writeDelay + writeEnd + 0.7);
later(cycle, writeDelay + writeEnd + 0.7 + settleHold);
}
var running = false;
function start() { if (running) { return; } running = true; cycle(); }
function stop() { running = false; timers.forEach(window.clearTimeout); timers = []; }
if ('IntersectionObserver' in window) {
new IntersectionObserver(function (entries) {
entries.forEach(function (entry) { if (entry.isIntersecting) { start(); } else { stop(); } });
}, { threshold: 0.25 }).observe(page);
} else {
start();
}
document.addEventListener('visibilitychange', function () {
if (document.hidden) { stop(); } else if (!running) { start(); }
});
})();