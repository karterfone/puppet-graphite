# == Class: graphite::install
#
# This class installs graphite packages via pip
#
# === Parameters
#
# None.
#
class graphite::install inherits graphite::params {
  # # Validate
  if $caller_module_name != $module_name {
    fail("Use of private class ${name} by ${caller_module_name}")
  }

  if $::graphite::gr_pip_install and $::osfamily == 'RedHat' {
    validate_re($::operatingsystemrelease, '^[6-8]\.\d+|^20\d{2}.\d{2}', "Unsupported RedHat release: '${::operatingsystemrelease}'"
    )
  }

  $pip_install_options = $::graphite::params::extra_pip_install_options ? {
    undef   => $::graphite::gr_pip_install_options,
    default => union(
      $::graphite::params::extra_pip_install_options,
      pick($::graphite::gr_pip_install_options, [])
    )
  }

  # # Set class variables
  $gr_pkg_provider = pick_default($::graphite::gr_pip_provider, $::graphite::gr_pip_install ? {
      true    => 'pip',
      default => undef,
    }
  )

  if $::graphite::gr_manage_python_packages {
    $gr_pkg_require = $::graphite::gr_pip_install ? {
      true    => [
        Package[$::graphite::params::graphitepkgs],
        Package[$::graphite::params::python_pip_pkg],
        Package[$::graphite::params::python_dev_pkg],
        ],
      default => [Package[$::graphite::params::graphitepkgs]],
    }
  } else {
    $gr_pkg_require = [Package[$::graphite::params::graphitepkgs]]
  }

  # # Manage resources

  # for full functionality we need these packages:
  # madatory: python-cairo, python-django, python-twisted,
  #           python-django-tagging, python-simplejson
  # optional: python-ldap, python-memcache, memcached, python-sqlite

  #  ensure_packages($::graphite::params::graphitepkgs)
  #
  #  create_resources('package', {
  #    'carbon'         => {
  #      ensure  => $::graphite::gr_carbon_ver,
  #      name    => $::graphite::gr_carbon_pkg,
  #      source  => $::graphite::gr_carbon_source,
  #    }
  #    ,
  #    'django-tagging' => {
  #      ensure => $::graphite::gr_django_tagging_ver,
  #      name   => $::graphite::gr_django_tagging_pkg,
  #      source => $::graphite::gr_django_tagging_source,
  #    }
  #    ,
  #    'graphite-web'   => {
  #      ensure => $::graphite::gr_graphite_ver,
  #      name   => $::graphite::gr_graphite_pkg,
  #      source => $::graphite::gr_graphite_source,
  #    }
  #    ,
  #    'twisted'        => {
  #      ensure => $::graphite::gr_twisted_ver,
  #      name   => $::graphite::gr_twisted_pkg,
  #      source => $::graphite::gr_twisted_source,
  #      before => [Package['txamqp'], Package['carbon'],],
  #    }
  #    ,
  #    'txamqp'         => {
  #      ensure => $::graphite::gr_txamqp_ver,
  #      name   => $::graphite::gr_txamqp_pkg,
  #      source => $::graphite::gr_txamqp_source,
  #      before => [
  #        Package['carbon'],
  #        ],
  #    }
  #    ,
  #    'whisper'        => {
  #      ensure => $::graphite::gr_whisper_ver,
  #      name   => $::graphite::gr_whisper_pkg,
  #      source => $::graphite::gr_whisper_source,
  #    }
  #    ,
  #  }
  #  , {
  #    provider        => $gr_pkg_provider,
  #    require         => $gr_pkg_require,
  #    install_options => $gr_pkg_provider ? {
  #      'pip'   => $pip_install_options,
  #      default => undef,
  #    },
  #  }
  #  )

  if $::graphite::gr_django_pkg {
    $django_install_options = $::graphite::gr_django_provider ? {
      'pip'   => $pip_install_options,
      default => undef,
    }
    package { $::graphite::gr_django_pkg:
      ensure          => $::graphite::gr_django_ver,
      provider        => $::graphite::gr_django_provider,
      source          => $::graphite::gr_django_source,
      require         => $gr_pkg_require,
      install_options => $django_install_options,
    }
  }

  if $::graphite::gr_pip_install {
    # using the pip package provider requires python-pip
    # also install python headers and libs for pip
    if $::graphite::gr_manage_python_packages {
      ensure_packages(flatten([$::graphite::params::python_pip_pkg, $::graphite::params::python_dev_pkg,]))
    }

    # hack unusual graphite install target
    $carbon = "carbon-${::graphite::gr_carbon_ver}-py${::graphite::params::pyver}.egg-info"
    $gweb = "graphite_web-${::graphite::gr_graphite_ver}-py${::graphite::params::pyver}.egg-info"
    exec{ 'gweb_hack':
        command   => "ln -s '${::graphite::base_dir_REAL}/webapp/${gweb}' '${::graphite::params::libpath}/'",
        unless    => "test -L '${::graphite::params::libpath}/${gweb}'",
        provider  => 'shell',
        subscribe => Package['graphite-web']
    }
    exec{ 'carbon_hack':
        command   => "ln -s '${::graphite::base_dir_REAL}/lib/${carbon}' '${::graphite::params::libpath}/'",
        unless    => "test -L '${::graphite::params::libpath}/${carbon}'",
        provider  => 'shell',
        subscribe => Package['carbon']
    }
    # Purge duplicate egg-info files having the wrong version
    exec{ 'Purge old graphite-web egg-info':
        command   => "find '${::graphite::base_dir_REAL}/webapp' '${::graphite::params::libpath}' -iname 'graphite_web-*.egg-info' -not  -iname '${gweb}' | xargs rm -rf",
        onlyif    => "ls -d \"${::graphite::base_dir_REAL}/webapp/\"graphite_web*.egg-info \"${::graphite::params::libpath}/\"graphite_web*.egg-info | grep -v '${gweb}'",
        path      => '/bin:/usr/bin',
        provider  => 'shell',
        subscribe => Package['graphite-web']
    }
    exec{ 'Purge old carbon egg-info':
        command   => "find '${::graphite::base_dir_REAL}/lib' '${::graphite::params::libpath}' -iname 'carbon-*.egg-info' -not  -iname '${carbon}' | xargs rm -rf",
        onlyif    => "ls -d \"${::graphite::base_dir_REAL}/lib/\"carbon*.egg-info \"${::graphite::params::libpath}/\"carbon*.egg-info | grep -v '${carbon}'",
        path      => '/bin:/usr/bin',
        provider  => 'shell',
        subscribe => Package['carbon']
    }
  }
}
