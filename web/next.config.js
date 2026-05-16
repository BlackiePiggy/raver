/** @type {import('next').NextConfig} */
const apiBase = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:3901/api';
const backendOrigin = apiBase.replace(/\/api\/?$/, '');
const festivalViewerOrigin = process.env.FESTIVAL_VIEWER_ORIGIN || 'http://127.0.0.1:8000';

const nextConfig = {
  images: {
    domains: ['localhost'],
    remotePatterns: [
      {
        protocol: 'http',
        hostname: '**',
      },
      {
        protocol: 'https',
        hostname: '**',
      },
    ],
  },
  async rewrites() {
    return [
      {
        source: '/admin/festival-viewer.html',
        destination: `${festivalViewerOrigin}/festival-viewer.html`,
      },
      {
        source: '/admin/festival-viewer/:path*',
        destination: `${festivalViewerOrigin}/festival-viewer/:path*`,
      },
      {
        source: '/admin/country-codes-iso3166.js',
        destination: `${festivalViewerOrigin}/country-codes-iso3166.js`,
      },
      {
        source: '/api/raver/:path*',
        destination: `${festivalViewerOrigin}/api/raver/:path*`,
      },
      {
        source: '/api/viewer/:path*',
        destination: `${festivalViewerOrigin}/api/viewer/:path*`,
      },
      {
        source: '/api/coze/:path*',
        destination: `${festivalViewerOrigin}/api/coze/:path*`,
      },
      {
        source: '/api/scrape/:path*',
        destination: `${festivalViewerOrigin}/api/scrape/:path*`,
      },
      {
        source: '/api/dj-source-cache/:path*',
        destination: `${festivalViewerOrigin}/api/dj-source-cache/:path*`,
      },
      {
        source: '/api/proxy-image',
        destination: `${festivalViewerOrigin}/api/proxy-image`,
      },
      {
        source: '/api/open-folder',
        destination: `${festivalViewerOrigin}/api/open-folder`,
      },
      {
        source: '/api/search',
        destination: `${festivalViewerOrigin}/api/search`,
      },
      {
        source: '/api/:path*',
        destination: `${backendOrigin}/api/:path*`,
      },
      {
        source: '/v1/:path*',
        destination: `${backendOrigin}/v1/:path*`,
      },
      {
        source: '/uploads/:path*',
        destination: `${backendOrigin}/uploads/:path*`,
      },
    ];
  },
}

module.exports = nextConfig
