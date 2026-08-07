/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `now` command */
  export type Now = ExtensionPreferences & {}
  /** Preferences accessible in the `iso` command */
  export type Iso = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `now` command */
  export type Now = {}
  /** Arguments passed to the `iso` command */
  export type Iso = {
  /** Unix ms (default: now) */
  "timestamp": string
}
}

