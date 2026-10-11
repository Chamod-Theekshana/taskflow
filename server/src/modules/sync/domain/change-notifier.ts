/**
 * Port: tells a user's other devices that their data changed, so they sync.
 * Called after a transaction commits, never inside it.
 */
export interface ChangeNotifier {
  changed(userId: string, originInstallationId?: string): void;
}

export const noopChangeNotifier: ChangeNotifier = {
  changed: () => undefined,
};
