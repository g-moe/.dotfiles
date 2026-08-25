import type { UsageProviderId, UsageSnapshot } from "./usage.js";

export interface IProvider<TAuth = unknown, TRawUsage = unknown> {
	readonly id: UsageProviderId;
	readonly displayName: string;
	_getAuth(): TAuth | Promise<TAuth>;
	_fetchUsage(auth: TAuth): Promise<TRawUsage>;
	_parseUsage(rawUsage: TRawUsage): UsageSnapshot;
	getUsage(): Promise<UsageSnapshot>;
}
