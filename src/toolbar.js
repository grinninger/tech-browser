'use strict';

const address = document.querySelector('#address');
const back = document.querySelector('#back');
const forward = document.querySelector('#forward');
const reload = document.querySelector('#reload');
const home = document.querySelector('#home');
const status = document.querySelector('#status');
const form = document.querySelector('#address-form');
let currentDownloadPath = '';

function renderState(state = {}) {
  if (document.activeElement !== address && typeof state.url === 'string') address.value = state.url;
  back.disabled = !state.canGoBack;
  forward.disabled = !state.canGoForward;
  reload.textContent = state.loading ? '\u00d7' : '\u21bb';
  reload.title = state.loading ? 'Laden stoppen' : 'Neu laden';
  document.title = state.title ? `${state.title} – Tech Browser` : 'Tech Browser';

  if (state.message) {
    status.textContent = state.message;
    currentDownloadPath = state.downloadPath || '';
    status.classList.toggle('action', Boolean(currentDownloadPath));
  } else if (state.loading) {
    status.textContent = 'Lädt …';
    currentDownloadPath = '';
    status.classList.remove('action');
  } else {
    status.textContent = '';
    currentDownloadPath = '';
    status.classList.remove('action');
  }
}

form.addEventListener('submit', (event) => {
  event.preventDefault();
  window.techBrowser.navigate(address.value);
  address.blur();
});

address.addEventListener('focus', () => address.select());
back.addEventListener('click', () => window.techBrowser.back());
forward.addEventListener('click', () => window.techBrowser.forward());
home.addEventListener('click', () => window.techBrowser.home());
reload.addEventListener('click', async () => {
  const state = await window.techBrowser.getState();
  if (state.loading) window.techBrowser.stop();
  else window.techBrowser.reload();
});
status.addEventListener('click', () => {
  if (currentDownloadPath) window.techBrowser.openDownload(currentDownloadPath);
});

window.techBrowser.onState(renderState);
window.techBrowser.getState().then(renderState);
