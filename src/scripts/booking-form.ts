// @ts-nocheck
import { submitBooking } from '../lib/booking';
const form = document.querySelector('[data-booking-form]');
if (form) {
  const base = form.dataset.base || '/';
  const selected = new URLSearchParams(location.search).get('ruta');
  if (selected) form.elements.route.value = selected;
  const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); form.elements.date.min = tomorrow.toISOString().slice(0, 10);
  form.addEventListener('submit', async (event) => {
    event.preventDefault(); let valid = true;
    form.querySelectorAll('[data-error-for]').forEach((node) => node.textContent = '');
    [...form.elements].forEach((field) => { if (field.willValidate && !field.checkValidity()) { valid = false; const error = form.querySelector(`[data-error-for="${field.name}"]`); if (error) error.textContent = field.validity.valueMissing ? 'Completa este campo.' : 'Revisa este dato.'; } });
    if (!valid) { form.querySelector(':invalid')?.focus(); return; }
    const button = form.querySelector('[type=submit]'); const message = form.querySelector('[data-form-message]');
    button.disabled = true; button.textContent = 'Enviando…'; message.hidden = true;
    try {
      const e=form.elements; const result=await submitBooking({route:e.route.value,date:e.date.value,time:e.time.value,language:e.language.value,people:Number(e.people.value),modality:e.modality.value,name:e.name.value.trim(),email:e.email.value.trim(),phone:e.phone.value.trim(),notes:e.notes.value.trim(),website:e.website.value});
      const routeTitle=e.route.options[e.route.selectedIndex]?.textContent?.split(' · ')[0]||e.route.value;
      sessionStorage.setItem('rutasb-last-request',JSON.stringify({route:e.route.value,routeTitle,name:e.name.value,date:e.date.value,reference:result.reference,mode:result.mode,duplicate:result.duplicate})); location.href=`${base}confirmacion/`;
    } catch { message.textContent='No pudimos registrar la solicitud. Inténtalo nuevamente.'; message.hidden=false; button.disabled=false; button.textContent='Enviar solicitud'; }
  });
}
