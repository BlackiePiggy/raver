import DJSetUploader from '@/components/DJSetUploader';
import Navigation from '@/components/Navigation';

export default function UploadPage() {
  return (
    <div className="min-h-screen bg-bg-primary">
      <Navigation />
      <div className="pt-[44px]">
        <DJSetUploader />
      </div>
    </div>
  );
}