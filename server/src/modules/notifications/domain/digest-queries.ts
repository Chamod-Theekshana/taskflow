/** Read-side queries the daily digest needs. */
export interface DigestCandidate {
  userId: string;
  timezone: string;
  /** `HH:mm` */
  digestTime: string;
}

export interface DigestQueries {
  /**
   * Users with the digest switched on that have at least one device which
   * relies on the server for it (the mobile app builds its digest locally).
   */
  candidates(): Promise<DigestCandidate[]>;
  /** Open tasks due on [date] (`YYYY-MM-DD`) and how many of them are high priority. */
  dayCounts(userId: string, date: string): Promise<{ due: number; high: number }>;
}
