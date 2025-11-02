import { Ok, Error } from "../gleam.mjs";

export function fromEnv(key) {
  // Access environment variables injected by the build process
  if (typeof window !== 'undefined' && window.ENV) {
    return window.ENV[key] || "";
  }
  return "";
}

export function dbg(v) {
  console.debug(v)
}

export function stringify(v) {
  return JSON.stringify(v, null, 2)
}

export function redirectToUrl(url) {
  if (typeof window !== 'undefined') {
    window.location.href = url;
  }
}

export function getCurrentPath() {
  if (typeof window !== 'undefined') {
    return window.location.pathname;
  }
  return "/";
}

export function getLocalstorage(key) {
  const value = window.localStorage.getItem(key);
  return value ? new Ok(value) : new Error(undefined);
}

export function error(msg) {
  console.error(msg);
}

export function warn(msg) {
  console.warn(msg);
}

export function info(msg) {
  console.info(msg);
}

export function log(msg) {
  console.log(msg);
}

export function trace(msg) {
  console.trace(msg);
}

export function debug(msg) {
  console.debug(msg);
}
