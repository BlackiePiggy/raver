import { ShareLink, PrismaClient } from '@prisma/client';
import { readShareLinkPosterVariant } from './localization';
import { resolveSharePosterHandler } from './registry';
import { SharePosterLocale, SharePosterRenderResult, SharePosterRequestContext } from './types';

type RenderSharePosterInput = {
  prisma: PrismaClient;
  shareLink: ShareLink;
  locale: SharePosterLocale;
  variant?: string | null;
};

export const renderSharePoster = async (input: RenderSharePosterInput): Promise<SharePosterRenderResult> => {
  const context: SharePosterRequestContext = {
    prisma: input.prisma,
    shareLink: input.shareLink,
    locale: input.locale,
    variant: input.variant ?? readShareLinkPosterVariant(input.shareLink.metadata),
  };
  const handler = resolveSharePosterHandler(context);
  console.info(
    `[share-poster] code=${context.shareLink.code} targetType=${context.shareLink.targetType} handler=${handler.id} variant=${context.variant || 'default'}`
  );
  const result = await handler.render(context);
  if (result) return result;
  throw new Error(`Share poster handler "${handler.id}" returned no poster`);
};

export * from './localization';
export * from './types';
