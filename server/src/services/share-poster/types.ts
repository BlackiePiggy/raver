import { PrismaClient, ShareLink } from '@prisma/client';

export type SharePosterLocale = 'zh' | 'en';

export type PosterRenderMode =
  | 'event_svg'
  | 'event_fallback_png'
  | 'event_timetable_svg'
  | 'dj_svg'
  | 'user_card_svg'
  | 'festival_svg'
  | 'default_svg';

export type SharePosterSectionCell = {
  label: string;
  value: string;
};

export type SharePosterSectionRow =
  | {
      kind: 'pair';
      left: SharePosterSectionCell;
      right: SharePosterSectionCell;
    }
  | {
      kind: 'full';
      cell: SharePosterSectionCell;
    };

export type SharePosterStructuredCardInput = {
  locale: SharePosterLocale;
  title: string;
  imageUrl?: string | null;
  rows: SharePosterSectionRow[];
  footerLine1: string;
  footerLine2: string;
  qrText: string;
  mode: Exclude<PosterRenderMode, 'event_fallback_png'>;
};

export type SharePosterRequestContext = {
  prisma: PrismaClient;
  shareLink: ShareLink;
  locale: SharePosterLocale;
  variant: string | null;
};

export type SharePosterRenderResult = {
  png: Buffer;
  mode: PosterRenderMode;
  handlerId: string;
  variant: string | null;
};

export interface SharePosterHandler {
  id: string;
  supports(context: SharePosterRequestContext): boolean;
  render(context: SharePosterRequestContext): Promise<SharePosterRenderResult | null>;
}
