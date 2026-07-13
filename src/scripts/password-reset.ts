// @ts-nocheck
import { supabase } from '../lib/supabase';

const root = document.querySelector('[data-password-reset]');
if (root && supabase) {
  const form = root.querySelector('[data-reset-form]');
  const intro = root.querySelector('[data-reset-intro]');
  const errorNode = root.querySelector('[data-reset-error]');
  const linkError = root.querySelector('[data-reset-link-error]');
  const success = root.querySelector('[data-reset-success]');
  let ready = false;
  const enableForm = () => {
    if (ready) return;
    ready = true;
    intro.textContent = 'Crea una contraseña nueva para tu cuenta de administración.';
    form.hidden = false;
    linkError.textContent = '';
  };
  supabase.auth.onAuthStateChange((event, session) => {
    if (event === 'PASSWORD_RECOVERY' || session) enableForm();
  });
  supabase.auth.getSession().then(({ data, error }) => {
    if (data.session) enableForm();
    else if (error) linkError.textContent = 'El enlace no pudo validarse. Solicita uno nuevo desde el acceso privado.';
    else setTimeout(() => {
      if (!ready) {
        intro.textContent = '';
        linkError.textContent = 'El enlace es inválido o ha vencido. Solicita uno nuevo desde el acceso privado.';
      }
    }, 1500);
  });
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const button = form.querySelector('button[type="submit"]');
    errorNode.textContent = '';
    if (form.password.value !== form.confirmation.value) {
      errorNode.textContent = 'Las contraseñas no coinciden.';
      return;
    }
    button.disabled = true;
    try {
      const { error } = await supabase.auth.updateUser({ password: form.password.value });
      if (error) throw error;
      form.hidden = true;
      intro.hidden = true;
      success.hidden = false;
      await supabase.auth.signOut();
    } catch (error) {
      errorNode.textContent = error.message || 'No fue posible actualizar la contraseña.';
    } finally {
      button.disabled = false;
    }
  });
}