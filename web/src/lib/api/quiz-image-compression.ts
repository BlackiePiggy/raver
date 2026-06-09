type QuizImageCompressionProfile = 'stem' | 'option';
type QuizImageCompressionResult = {
  file: File;
  originalBytes: number;
  uploadedBytes: number;
  compressed: boolean;
};

type CompressionSettings = {
  maxWidth: number;
  maxHeight: number;
  quality: number;
  maxBytes: number;
};

const PROFILE_SETTINGS: Record<QuizImageCompressionProfile, CompressionSettings> = {
  stem: {
    maxWidth: 1600,
    maxHeight: 1600,
    quality: 0.84,
    maxBytes: 900 * 1024,
  },
  option: {
    maxWidth: 960,
    maxHeight: 960,
    quality: 0.82,
    maxBytes: 450 * 1024,
  },
};

const SKIP_MIME_TYPES = new Set(['image/gif', 'image/svg+xml']);

const replaceFileExtension = (name: string, nextExtension: string): string => {
  const normalizedName = name.trim() || 'quiz-image';
  const withoutExtension = normalizedName.replace(/\.[^.]+$/, '');
  return `${withoutExtension}${nextExtension}`;
};

const loadImageElement = (file: File): Promise<HTMLImageElement> =>
  new Promise((resolve, reject) => {
    const objectUrl = URL.createObjectURL(file);
    const image = new Image();

    image.onload = () => {
      URL.revokeObjectURL(objectUrl);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      reject(new Error('无法读取待压缩图片'));
    };
    image.src = objectUrl;
  });

const canvasToBlob = (
  canvas: HTMLCanvasElement,
  mimeType: string,
  quality: number
): Promise<Blob | null> =>
  new Promise((resolve) => {
    canvas.toBlob((blob) => resolve(blob), mimeType, quality);
  });

export const compressQuizImageForUpload = async (
  file: File,
  profile: QuizImageCompressionProfile
): Promise<QuizImageCompressionResult> => {
  const originalBytes = file.size;
  if (typeof window === 'undefined') {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }
  if (!file.type.startsWith('image/')) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }
  if (SKIP_MIME_TYPES.has(file.type)) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }

  const settings = PROFILE_SETTINGS[profile];
  const image = await loadImageElement(file);
  const scale = Math.min(
    1,
    settings.maxWidth / Math.max(1, image.naturalWidth),
    settings.maxHeight / Math.max(1, image.naturalHeight)
  );

  const targetWidth = Math.max(1, Math.round(image.naturalWidth * scale));
  const targetHeight = Math.max(1, Math.round(image.naturalHeight * scale));
  const shouldResize = targetWidth !== image.naturalWidth || targetHeight !== image.naturalHeight;
  const shouldReencode = file.size > settings.maxBytes || file.type !== 'image/webp';

  if (!shouldResize && !shouldReencode) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }

  const canvas = document.createElement('canvas');
  canvas.width = targetWidth;
  canvas.height = targetHeight;

  const context = canvas.getContext('2d');
  if (!context) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }

  context.drawImage(image, 0, 0, targetWidth, targetHeight);
  const compressedBlob = await canvasToBlob(canvas, 'image/webp', settings.quality);
  if (!compressedBlob || compressedBlob.size <= 0) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }

  if (compressedBlob.size >= file.size && !shouldResize) {
    return { file, originalBytes, uploadedBytes: file.size, compressed: false };
  }

  const compressedFile = new File([compressedBlob], replaceFileExtension(file.name, '.webp'), {
    type: 'image/webp',
    lastModified: Date.now(),
  });
  return {
    file: compressedFile,
    originalBytes,
    uploadedBytes: compressedFile.size,
    compressed: compressedFile.size !== originalBytes,
  };
};

export type { QuizImageCompressionProfile, QuizImageCompressionResult };
