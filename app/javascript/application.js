// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "page_agent"

// Login screen: fill the public demo operator credentials on request.
document.addEventListener("click", (event) => {
  const button = event.target instanceof Element ? event.target.closest(".login-demo-fill") : null
  const form = document.querySelector("[data-login-form]")
  if (!button || !form) return

  form.querySelector("input[name='email']").value = button.dataset.demoEmail
  form.querySelector("input[name='password']").value = button.dataset.demoPassword
  form.querySelector("input[type='submit']")?.focus()
})
