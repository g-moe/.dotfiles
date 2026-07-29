/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Machine 1 Name - Name shown in Raycast and in an open Screen Sharing window */
  "machine1Name"?: string,
  /** Machine 1 Address - Hostname or IP address */
  "machine1Address"?: string,
  /** Machine 2 Name - Name shown in Raycast and in an open Screen Sharing window */
  "machine2Name"?: string,
  /** Machine 2 Address - Hostname or IP address */
  "machine2Address"?: string,
  /** Machine 3 Name - Name shown in Raycast and in an open Screen Sharing window */
  "machine3Name"?: string,
  /** Machine 3 Address - Hostname or IP address */
  "machine3Address"?: string,
  /** Machine 4 Name - Name shown in Raycast and in an open Screen Sharing window */
  "machine4Name"?: string,
  /** Machine 4 Address - Hostname or IP address */
  "machine4Address"?: string,
  /** Machine 5 Name - Name shown in Raycast and in an open Screen Sharing window */
  "machine5Name"?: string,
  /** Machine 5 Address - Hostname or IP address */
  "machine5Address"?: string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `connections` command */
  export type Connections = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `connections` command */
  export type Connections = {}
}

