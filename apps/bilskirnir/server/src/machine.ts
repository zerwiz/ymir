import { env } from './env.js';
import { orgo, type OrgoComputer, type OrgoScreen } from './orgo.js';
import { LOCAL_DESK_ID, localDesk } from './desk-local.js';

/**
 * The one computer the agents work on, chosen by BILSKIRNIR_DESK: the hall's own desk (`local`, the
 * default) or an Orgo cloud computer (`orgo`). Both answer the same calls, so the rest of the app
 * never asks which one it has.
 */
export interface Machine {
  getComputer(id: string): Promise<OrgoComputer>;
  start(id: string): Promise<unknown>;
  resume(id: string): Promise<unknown>;
  vncPassword(id: string): Promise<{ password: string }>;
  listScreens(id: string): Promise<OrgoScreen[]>;
  createScreen(id: string): Promise<OrgoScreen>;
  getScreen(id: string, screen: string): Promise<OrgoScreen>;
  screenshot(id: string, screen?: string): Promise<{ image: string; mime_type?: string; width: number; height: number }>;
  bash(id: string, screen: string | undefined, command: string, timeout?: number): Promise<{ success: boolean; output: string; exit_code: number }>;
}

export const machine: Machine = env.desk === 'local' ? localDesk : orgo;

/** The computer's id, or '' when none is configured (Orgo without ORGO_COMPUTER_ID). */
export const machineId = (): string => (env.desk === 'local' ? LOCAL_DESK_ID : env.orgoComputerId);
