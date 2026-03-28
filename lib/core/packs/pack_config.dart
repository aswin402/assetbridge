
class PackConfig {
  const PackConfig({
    required this.name,
    required this.slug,
    this.owner,
    this.repo,
    this.svgPathPrefix,
  });

  final String name;
  /// Unique identifier (e.g., used for folder names).
  final String slug;
  /// GitHub repository owner (optional for local packs).
  final String? owner;
  /// GitHub repository name (optional for local packs).
  final String? repo;
  /// Optional path prefix to search for SVGs within the zip file.
  final String? svgPathPrefix;
}

const supportedPacks = [
  PackConfig(
    name: 'Phosphor',
    slug: 'phosphor',
    owner: 'phosphor-icons',
    repo: 'core',
    svgPathPrefix: 'assets',
  ),
  PackConfig(
    name: 'Tabler',
    slug: 'tabler',
    owner: 'tabler',
    repo: 'tabler-icons',
    svgPathPrefix: 'icons',
  ),
  PackConfig(
    name: 'Lucide',
    slug: 'lucide',
    owner: 'lucide-icons',
    repo: 'lucide',
    svgPathPrefix: 'icons',
  ),
  PackConfig(
    name: 'Heroicons',
    slug: 'heroicons',
    owner: 'tailwindlabs',
    repo: 'heroicons',
    svgPathPrefix: 'src',
  ),
  PackConfig(
    name: 'Material',
    slug: 'material',
    owner: 'google',
    repo: 'material-design-icons',
    svgPathPrefix: 'symbols/web',
  ),
];
