project('singularity-formula', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-formula"', language: 'c')
add_project_arguments('-w', language: 'c')
add_project_arguments(['--vapidir', meson.current_source_dir() / 'vapi'], language: 'vala')
subdir('po')

cc          = meson.get_compiler('c')
gee_dep     = dependency('gee-0.8')
gio_dep     = dependency('gio-2.0')
xml_dep     = dependency('libxml-2.0')
zlib_dep    = dependency('zlib')
cairo_dep   = dependency('cairo')
cairoft_dep = dependency('cairo-ft')
hb_dep      = dependency('harfbuzz')
ft_dep      = dependency('freetype2')
fc_dep      = dependency('fontconfig')
math_dep    = cc.find_library('m')

core_deps = [gee_dep, gio_dep, xml_dep, zlib_dep, cairo_dep, cairoft_dep, hb_dep, ft_dep, fc_dep, math_dep]
core_args = ['--pkg', 'zlib']

gtk_dep = dependency('gtk4')
libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

core = files(
  'src/model/node.vala',
  'src/model/symbols.vala',
  'src/model/unimath.vala',
  'src/model/fences.vala',
  'src/model/document.vala',
  'src/model/editor.vala',
  'src/model/gallery.vala',
  'src/syntax/latex_parser.vala',
  'src/syntax/latex_writer.vala',
  'src/syntax/mathml_writer.vala',
  'src/syntax/mathml_reader.vala',
  'src/syntax/unicodemath.vala',
  'src/syntax/starmath.vala',
  'src/layout/mathfont.vala',
  'src/layout/box.vala',
  'src/layout/layout.vala',
  'src/layout/render.vala',
  'src/io/zip.vala',
  'src/io/formats.vala',
  'src/io/word.vala',
  'src/io/cli.vala',
  'src/ink/ink.vala',
  'src/ink/recognizer.vala',
  'src/ink/structure.vala',
)

foreach t : ['latex', 'mathml', 'unicodemath', 'layout', 'editor', 'io', 'omml', 'ink', 'features']
  exe = executable('formula-' + t + '-test',
    core + files('tests/harness.vala', 'tests/' + t + '_test.vala'),
    dependencies: core_deps + [gtk_dep, libsingularity_dep],
    vala_args: core_args,
  )
  test(t, exe, env: ['FORMULA_FIXTURES=' + meson.current_source_dir() / 'tests' / 'fixtures'])
endforeach

ui = files(
  'src/ui/history.vala',
  'src/ui/preview.vala',
  'src/ui/canvas.vala',
  'src/ui/palette.vala',
  'src/ui/cloud_actions.vala',
  'src/ui/collab.vala',
  'src/ui/print_source.vala',
  'src/ui/ink_view.vala',
  'src/ui/autocorrect_view.vala',
  'src/ui/window.vala',
  'src/ui/app.vala',
  'src/ui/agent_intents.vala',
)

formula_exe = executable('singularity-formula',
  core + ui,
  dependencies: core_deps + [gtk_dep, libsingularity_dep, dependency('pangocairo')],
  vala_args: core_args,
  install: true
)

helper_test = executable('formula-helper-test',
  core + files('tests/harness.vala', 'tests/helper_test.vala'),
  dependencies: core_deps + [gtk_dep, libsingularity_dep],
  vala_args: core_args,
)
test('helper', helper_test,
  depends: formula_exe,
  env: ['FORMULA_FIXTURES=' + meson.current_source_dir() / 'tests' / 'fixtures', 'SINGULARITY_EQUATION_HELPER=' + formula_exe.full_path()],
  timeout: 120,
)

install_data('data/dev.sinty.formula.desktop',
  install_dir: get_option('datadir') / 'applications'
)
install_data('data/dev.sinty.formula.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)
install_data('data/dev.sinty.formula.json',
  install_dir: get_option('datadir') / 'singularity' / 'app-settings'
)
install_data('data/dev.sinty.formula.open.ini',
  install_dir: get_option('datadir') / 'singularity' / 'files-actions'
)
install_data('data/icons/dev.sinty.formula.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)

install_data('data/capabilities/dev.sinty.Collab.Formula1.ini',
  install_dir: get_option('datadir') / 'singularity' / 'capabilities')

service_conf = configuration_data()
service_conf.set('bindir', get_option('prefix') / get_option('bindir'))
configure_file(
  input: 'data/dev.sinty.formula.service.in',
  output: 'dev.sinty.formula.service',
  configuration: service_conf,
  install: true,
  install_dir: get_option('datadir') / 'dbus-1' / 'services'
)
