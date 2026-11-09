'use strict';
document.getElementById('deletion-form')?.addEventListener('submit', function(event) {
  event.preventDefault();
  if (!this.reportValidity()) return;
  const email = this.dataset.support;
  if (!email) return;
  const account = document.getElementById('account-email').value.trim();
  const note = document.getElementById('request-note').value.trim();
  const body = 'IQUM hesabımın ve ilişkili kişisel verilerimin silinmesini istiyorum.\nGiriş e-postam / Apple gizli adresim: '+account+'\n'+note;
  const uri = 'mailto:'+encodeURIComponent(email)+'?subject='+encodeURIComponent('IQUM hesap silme talebi')+'&body='+encodeURIComponent(body);
  document.getElementById('request-status').textContent = 'E-posta uygulaman açıldığında iletiyi gönder. Açılmazsa yukarıdaki destek adresine doğrudan yaz; henüz talep gönderilmiş sayılmaz.';
  window.location.href = uri;
});
