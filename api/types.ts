export type HeatLevel = "Blazing" | "Hot" | "Warm" | "Cooling" | "Cold" | "Ash";

export interface GitCommit {
  hash: string;
  message: string;
  date: string;
  author: string;
}

export interface CinderProject {
  id: string;
  name: string;
  path: string;
  stacks: string[];
  heat: HeatLevel;
  dormantDays: number;
  lastCommitDate: string | null;
  commitCountLastMonth: number;
  recentCommits: GitCommit[];
  isGitRepo: boolean;
  momentumLabel: string;
}

export interface HeatBreakdown {
  blazing: number;
  hot: number;
  warm: number;
  cooling: number;
  cold: number;
  ash: number;
}

export interface StatsResponse {
  totalProjects: number;
  archivedProjects: number;
  totalReignited: number;
  heatBreakdown: HeatBreakdown;
  generatedAt: string;
}

export interface DigestResponse {
  headline: string;
  summary: string;
  mostActive: string | null;
  mostUrgent: string | null;
  needsAttention: string[];
  hotProjects: string[];
  totalActive: number;
  totalArchived: number;
  generatedAt: string;
}

export interface ActionResponse {
  success: boolean;
  message: string;
}

export interface SwipeRecord {
  projectPath: string;
  projectName: string;
  direction: "reignite" | "snooze" | "archive";
  timestamp: string;
  snoozeUntil?: string;
}

export interface AppState {
  swipeRecords: SwipeRecord[];
}
