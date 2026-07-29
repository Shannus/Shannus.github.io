/*
 * Portfolio front-end wiring.
 * Safe to include on any page: every block no-ops if its target elements are absent.
 *
 * 1) Point API_BASE at your deployed API base URL (terraform output api_base_url),
 *    or expose it via <meta name="api-base" content="https://...">.
 * 2) Add the contact form markup and the status hooks shown in docs/RUNBOOK.md.
 */
(function () {
  "use strict";

  var meta = document.querySelector('meta[name="api-base"]');
  var API_BASE = (meta && meta.content) || window.API_BASE || "";
  if (API_BASE.slice(-1) === "/") API_BASE = API_BASE.slice(0, -1);

  // ---- Live status widget --------------------------------------------------
  // Any element with [data-status-badge] gets the overall status; a [data-version]
  // element gets the deployed version. Optional and fully defensive.
  function refreshStatus() {
    if (!API_BASE) return;
    var badge = document.querySelector("[data-status-badge]");
    var version = document.querySelector("[data-version]");
    if (!badge && !version) return;

    fetch(API_BASE + "/status", { cache: "no-store" })
      .then(function (r) { return r.ok ? r.json() : Promise.reject(r.status); })
      .then(function (data) {
        if (badge) badge.textContent = String(data.status || "unknown").toUpperCase();
        if (version) version.textContent = "v" + (data.version || "?");
      })
      .catch(function () {
        if (badge) badge.textContent = "UNREACHABLE";
      });
  }

  // ---- Contact form --------------------------------------------------------
  // Expects: <form id="contact-form"> with name="name", name="email", name="message",
  // and an optional element with id="contact-result" for feedback.
  function wireContactForm() {
    var form = document.getElementById("contact-form");
    if (!form) return;
    var result = document.getElementById("contact-result");

    form.addEventListener("submit", function (e) {
      e.preventDefault();
      if (!API_BASE) {
        if (result) result.textContent = "API base URL is not configured yet.";
        return;
      }
      var btn = form.querySelector('[type="submit"]');
      if (btn) btn.disabled = true;
      if (result) result.textContent = "Sending…";

      var payload = {
        name: (form.elements.name && form.elements.name.value) || "",
        email: (form.elements.email && form.elements.email.value) || "",
        message: (form.elements.message && form.elements.message.value) || ""
      };

      fetch(API_BASE + "/contact", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify(payload)
      })
        .then(function (r) { return r.json().then(function (b) { return { ok: r.ok, b: b }; }); })
        .then(function (res) {
          if (res.ok) {
            if (result) result.textContent = "Thanks — your message was received.";
            form.reset();
          } else {
            if (result) result.textContent = (res.b && res.b.error) || "Something went wrong.";
          }
        })
        .catch(function () {
          if (result) result.textContent = "Network error — please try again.";
        })
        .finally(function () { if (btn) btn.disabled = false; });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      refreshStatus();
      wireContactForm();
    });
  } else {
    refreshStatus();
    wireContactForm();
  }
})();
