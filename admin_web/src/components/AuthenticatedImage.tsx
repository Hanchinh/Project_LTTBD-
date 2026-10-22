import React, { useEffect, useState } from 'react';
import { getPhotoBlobUrl } from '../api/client';

interface AuthenticatedImageProps {
  src?: string | null;
  alt?: string;
  className?: string;
  fallbackText?: string;
  isThumbnail?: boolean;
}

export const AuthenticatedImage: React.FC<AuthenticatedImageProps> = ({
  src,
  alt = 'Ảnh vị trí',
  className = '',
  fallbackText = 'Không tải được ảnh',
  isThumbnail = false,
}) => {
  const [blobUrl, setBlobUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);
  const [error, setError] = useState<boolean>(false);

  useEffect(() => {
    if (!src) {
      setBlobUrl(null);
      setError(false);
      setLoading(false);
      return;
    }

    let isMounted = true;
    let createdUrl: string | null = null;

    setLoading(true);
    setError(false);

    getPhotoBlobUrl(src)
      .then((url) => {
        if (!isMounted) {
          URL.revokeObjectURL(url);
          return;
        }
        createdUrl = url;
        setBlobUrl(url);
      })
      .catch((err) => {
        if (isMounted) {
          console.error('Lỗi tải ảnh bảo mật:', err);
          setError(true);
        }
      })
      .finally(() => {
        if (isMounted) {
          setLoading(false);
        }
      });

    return () => {
      isMounted = false;
      if (createdUrl) {
        URL.revokeObjectURL(createdUrl);
      }
    };
  }, [src]);

  if (!src) {
    return <span className="text-xs text-gray-400 italic">Chưa có ảnh</span>;
  }

  if (loading) {
    return (
      <div
        className={`flex items-center justify-center bg-gray-100 text-gray-400 text-xs rounded animate-pulse ${className}`}
      >
        <span>Đang tải...</span>
      </div>
    );
  }

  if (error || !blobUrl) {
    return (
      <div
        className={`flex items-center justify-center bg-gray-50 text-gray-400 text-xs border border-dashed border-gray-200 rounded p-1 text-center ${className}`}
      >
        <span>{fallbackText}</span>
      </div>
    );
  }

  return (
    <img
      src={blobUrl}
      alt={alt}
      className={className}
      onClick={() => {
        if (blobUrl) {
          window.open(blobUrl, '_blank');
        }
      }}
      title="Nhấn để xem ảnh gốc trong tab mới"
      style={{ cursor: 'pointer' }}
    />
  );
};
