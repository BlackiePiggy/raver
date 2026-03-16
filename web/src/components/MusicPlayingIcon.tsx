export default function MusicPlayingIcon() {
  return (
    <div className="flex items-center gap-[2px] h-4">
      <div className="w-[3px] bg-primary-blue rounded-full animate-music-bar-1" style={{ height: '100%' }}></div>
      <div className="w-[3px] bg-primary-blue rounded-full animate-music-bar-2" style={{ height: '100%' }}></div>
      <div className="w-[3px] bg-primary-blue rounded-full animate-music-bar-3" style={{ height: '100%' }}></div>
      <div className="w-[3px] bg-primary-blue rounded-full animate-music-bar-4" style={{ height: '100%' }}></div>
    </div>
  );
}