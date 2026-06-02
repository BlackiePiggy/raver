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
        source: '/.well-known/apple-app-site-association',
        destination: `${backendOrigin}/.well-known/apple-app-site-association`,
      },
      {
        source: '/apple-app-site-association',
        destination: `${backendOrigin}/apple-app-site-association`,
      },
      {
        source: '/download',
        destination: `${backendOrigin}/download`,
      },
      {
        source: '/s/:path*',
        destination: `${backendOrigin}/s/:path*`,
      },
      {
        source: '/qr/:path*',
        destination: `${backendOrigin}/qr/:path*`,
      },
      {
        source: '/poster/:path*',
        destination: `${backendOrigin}/poster/:path*`,
      },
      {
        source: '/api/raver/events/:eventId/update',
        destination: `${backendOrigin}/v1/events/:eventId`,
      },
      {
        source: '/api/raver/:path((?!events/[^/]+/update$).*)',
        destination: `${festivalViewerOrigin}/api/raver/:path*`,
      },
      {
        source: '/api/coze/:path((?!normalize-event-location$).*)',
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
