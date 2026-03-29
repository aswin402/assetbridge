
class PackConfig {
  const PackConfig({
    required this.name,
    required this.slug,
    this.owner,        
    this.repo,         
    this.svgPathPrefix,
    this.isUiKit = false,
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

  /// Whether this is a UI Kit (contains a .sketch file) or an Icon Pack.
  final bool isUiKit;
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
  PackConfig(
    name: 'Tailwind CSS Sketch Kit',
    slug: 'tailwindcss_sketch_kit',
    owner: 'jessedobbelaere',
    repo: 'tailwindcss-sketch-kit',
    isUiKit: true,
  ),
  PackConfig(
    name: 'Mobify UI Kit',
    slug: 'mobify_ui_kit',
    owner: 'mobify',
    repo: 'ui-kit',
    isUiKit: true,
  ),
  PackConfig(
    name: 'macOS UI Kit',
    slug: 'macos_ui_kit',
    owner: 'alexkaessner',
    repo: 'macOS-UI-Kit',
    isUiKit: true,
  ),
];
