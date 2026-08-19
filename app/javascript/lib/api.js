// Thin fetch wrapper shared by the game's Stimulus controllers.
//
// All player-facing JSON endpoints (Game::BaseController subclasses) expect
// the Rails CSRF token on non-GET requests and reply with JSON. This module
// centralizes that contract so controllers don't repeat header boilerplate.

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : null
}

function buildHeaders(hasBody) {
  const headers = { Accept: "application/json" }
  const token = csrfToken()

  if (token) {
    headers["X-CSRF-Token"] = token
  }

  if (hasBody) {
    headers["Content-Type"] = "application/json"
  }

  return headers
}

async function request(method, url, body) {
  const hasBody = body !== undefined
  const response = await fetch(url, {
    method,
    credentials: "same-origin",
    headers: buildHeaders(hasBody),
    body: hasBody ? JSON.stringify(body) : undefined,
  })

  if (!response.ok) {
    const error = new Error(`${method} ${url} failed with ${response.status}`)
    error.status = response.status
    error.response = response
    throw error
  }

  if (response.status === 204) {
    return null
  }

  return response.json()
}

export function get(url) {
  return request("GET", url)
}

export function post(url, body = {}) {
  return request("POST", url, body)
}

export function patch(url, body = {}) {
  return request("PATCH", url, body)
}
