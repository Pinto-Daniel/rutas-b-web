// @ts-nocheck
import { supabase } from '../lib/supabase';
import { signInAdmin, getAdminDashboard } from '../lib/admin';

const app = document.querySelector('[data-admin-app]');

if (app) {
  const login = app.querySelector('[data-login-view]');
  const dashboard = app.querySelector('[data-dashboard]');
  const sidebar = app.querySelector('[data-admin-sidebar]');
  const errorNode = app.querySelector('[data-admin-error]');
  const loginForm = app.querySelector('[data-login-form]');
  const recoveryForm = app.querySelector('[data-recovery-form]');
  const recoveryError = app.querySelector('[data-recovery-error]');
  const recoveryMessage = app.querySelector('[data-recovery-message]');
  const setError = (message = '') => { errorNode.textContent = message; };
  const showRecovery = (show) => {
    loginForm.hidden = show;
    recoveryForm.hidden = !show;
    recoveryError.textContent = '';
    recoveryMessage.textContent = '';
  };

  async function load() {
    const data = await getAdminDashboard();
    login.hidden = true;
    dashboard.hidden = false;
    sidebar.hidden = false;
    app.querySelector('[data-admin-name]').textContent = data.profile.display_name || 'Administrador';
    const counts = { received: 0, reviewing: 0, confirmed: 0, total: data.bookings.length };
    data.bookings.forEach((booking) => {
      if (counts[booking.status] !== undefined) counts[booking.status]++;
    });
    Object.entries(counts).forEach(([key, value]) => {
      app.querySelector(`[data-metric="${key}"]`).textContent = String(value);
    });
    const body = app.querySelector('[data-bookings-body]');
    body.innerHTML = '';
    data.bookings.forEach((booking) => {
      const customer = Array.isArray(booking.customers) ? booking.customers[0] : booking.customers;
      const route = Array.isArray(booking.routes) ? booking.routes[0] : booking.routes;
      const row = document.createElement('tr');
      row.innerHTML = `<td><strong>${booking.public_reference}</strong></td><td>${customer?.full_name || '—'}<small>${customer?.email || ''}</small></td><td>${route?.title || '—'}</td><td>${booking.preferred_date}</td><td>${booking.participant_count}</td><td><span class="booking-state ${booking.status}">${booking.status}</span></td>`;
      body.appendChild(row);
    });
    app.querySelector('[data-admin-empty]').hidden = data.bookings.length > 0;
  }

  loginForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const button = form.querySelector('button[type="submit"]');
    button.disabled = true;
    try {
      await signInAdmin(form.email.value, form.password.value);
      await load();
    } catch (error) {
      setError(error.message || 'No fue posible entrar.');
    } finally {
      button.disabled = false;
      button.textContent = 'Entrar';
    }
  });

  app.querySelector('[data-show-recovery]')?.addEventListener('click', () => showRecovery(true));
  app.querySelector('[data-cancel-recovery]')?.addEventListener('click', () => showRecovery(false));
  recoveryForm?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const button = form.querySelector('button[type="submit"]');
    button.disabled = true;
    recoveryError.textContent = '';
    recoveryMessage.textContent = '';
    try {
      const base = app.dataset.base || '/';
      const redirectTo = new URL(`${base}admin/restablecer/`, window.location.origin).toString();
      const { error } = await supabase.auth.resetPasswordForEmail(form.email.value, { redirectTo });
      if (error) throw error;
      recoveryMessage.textContent = 'Si el correo está registrado, recibirás un enlace para crear una contraseña nueva. Revisa también la carpeta de spam.';
      form.reset();
    } catch (error) {
      recoveryError.textContent = error.message || 'No fue posible enviar el enlace.';
    } finally {
      button.disabled = false;
    }
  });

  app.querySelector('[data-refresh]')?.addEventListener('click', () => load().catch((error) => setError(error.message)));
  app.querySelector('[data-signout]')?.addEventListener('click', async () => { await supabase?.auth.signOut(); location.reload(); });
  app.querySelectorAll('[data-admin-view]').forEach((button) => button.addEventListener('click', () => {
    app.querySelectorAll('[data-admin-view]').forEach((item) => item.classList.remove('active'));
    button.classList.add('active');
    app.querySelectorAll('[data-view]').forEach((view) => { view.hidden = view.dataset.view !== button.dataset.adminView; });
  }));
  if (supabase) supabase.auth.getSession().then(({ data }) => { if (data.session) load().catch(() => supabase.auth.signOut()); });
}