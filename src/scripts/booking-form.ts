// @ts-nocheck
import { notifyBooking, submitBooking } from '../lib/booking';
const form = document.querySelector('[data-booking-form]');
if (form) {
  const base = form.dataset.base || '/';
  const selected = new URLSearchParams(location.search).get('ruta');
  if (selected) form.elements.route.value = selected;
  const tomorrow = new Date(); tomorrow.setDate(tomorrow.getDate() + 1); form.elements.date.min = tomorrow.toISOString().slice(0, 10);

  const syncTimeSlots = () => {
    const dateValue = form.elements.date.value;
    const timeSelect = form.elements.time;
    const previous = timeSelect.value;
    timeSelect.replaceChildren();
    const placeholder = new Option(dateValue ? 'Selecciona una hora' : 'Selecciona primero una fecha', '');
    timeSelect.add(placeholder);
    timeSelect.disabled = !dateValue;
    if (!dateValue) return;
    const day = new Date(`${dateValue}T12:00:00`).getDay();
    const weekend = day === 0 || day === 6;
    const slots = weekend ? ['10:00', '12:00', '18:00', '22:00'] : ['18:00', '22:00'];
    slots.forEach((slot) => timeSelect.add(new Option(slot, slot)));
    if (slots.includes(previous)) timeSelect.value = previous;
  };
  form.elements.date.addEventListener('change', syncTimeSlots);
  form.elements.date.addEventListener('click', () => { try { form.elements.date.showPicker?.(); } catch {} });
  syncTimeSlots();

  form.addEventListener('submit', async (event) => {
    event.preventDefault(); let valid = true;
    form.querySelectorAll('[data-error-for]').forEach((node) => node.textContent = '');
    [...form.elements].forEach((field) => { if (field.willValidate && !field.checkValidity()) { valid = false; const error = form.querySelector(`[data-error-for="${field.name}"]`); if (error) error.textContent = field.validity.valueMissing ? 'Completa este campo.' : 'Revisa este dato.'; } });
    if (!valid) { form.querySelector(':invalid')?.focus(); return; }
    const button = form.querySelector('[type=submit]'); const message = form.querySelector('[data-form-message]');
    button.disabled = true; button.textContent = 'Reservando…'; message.hidden = true;
    try {
      const e=form.elements; const result=await submitBooking({route:e.route.value,date:e.date.value,time:e.time.value,language:e.language.value,people:Number(e.people.value),modality:e.partnerBooking.checked?'partner':'private',name:e.name.value.trim(),email:e.email.value.trim(),phone:e.phone.value.trim(),notes:e.notes.value.trim(),website:e.website.value});
      const emailSent = result.mode === 'connected' ? await notifyBooking(result.reference) : false;
      const routeTitle=e.route.options[e.route.selectedIndex]?.textContent||e.route.value;
      const timeLabel=e.time.options[e.time.selectedIndex]?.textContent||e.time.value;
      sessionStorage.setItem('rutasb-last-request',JSON.stringify({route:e.route.value,routeTitle,name:e.name.value,date:e.date.value,time:e.time.value,timeLabel,reference:result.reference,mode:result.mode,duplicate:result.duplicate,emailSent})); location.href=`${base}confirmacion/`;
    } catch { message.textContent='No pudimos registrar la reserva. Inténtalo nuevamente.'; message.hidden=false; button.disabled=false; button.textContent='Reservar ruta'; }
  });
}
