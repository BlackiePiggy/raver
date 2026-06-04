import RankingBoardStudioForm from '@/components/admin/RankingBoardStudioForm';

export default async function AdminRankingEditPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const { id } = await params;
  return <RankingBoardStudioForm mode="edit" boardId={id} />;
}
