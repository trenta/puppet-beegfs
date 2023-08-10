# Manages APT repositories for Debian distros
#
# @param manage_repo
# @param package_source
# @param release
# @param gpg_key_id
# @param dist

class beegfs::repo::debian (
  Boolean          $manage_repo    = true,
  Enum['beegfs']   $package_source = $beegfs::package_source,
  Beegfs::Release  $release        = $beegfs::repo::release,
  String           $gpg_key_id     = '055D000F1A9A092763B1F0DD14E8E08064497785',
  Optional[String] $dist           = undef,
) {
  include apt

  # If using version 7.1 the release folder has an underscore instead of a period
  $_release = if $release == '7.1' {
    $release.regsubst('\.', '_')
  } else {
    $release
  }

  case $release {
    '2015.03','6': {
      # no semantic versioning
      $_gpg_key = 'DEB-GPG-KEY-beegfs'
    }
    default: {
      $_gpg_key = if versioncmp($release, '7.2.5') > 0 {
        'GPG-KEY-beegfs'
      } else {
        'DEB-GPG-KEY-beegfs'
      }
    }
  }

  if $dist {
    $_os_release = $dist
  } else {
    case $release {
      '2015.03','6': {
        # 'deb8', 'deb9', etc.
        $major = $facts.dig('os', 'release', 'major')
        $_os_release = "deb${major}"
      }
      # '7' onwards uses traditional Debian codename
      default: {
        case $facts.dig('os', 'name') {
          # https://askubuntu.com/questions/445487/what-debian-version-are-the-different-ubuntu-versions-based-on
          'Ubuntu': {
            case $facts.dig('os', 'release', 'full') {
              '14.04','14.10','15.04','15.10':{
                $_os_release = 'deb8'
              }
              '16.04','16.10','17.04','17.10':{
                $_os_release = 'stretch'
              }
              '18.04','18.10','19.04','19.10':{
                $_os_release = 'buster'
              }
              default: {
                $_os_release = 'buster'
              }
            }
          }
          default: {
            $_os_release = $facts.dig('os', 'distro', 'codename')
          }
        }
      }
    }
  }

  if $manage_repo {
    case $package_source {
      'beegfs': {
        apt::source { 'beegfs':
          location     => "http://www.beegfs.io/release/beegfs_${_release}",
          repos        => 'non-free',
          architecture => 'amd64',
          release      => $_os_release,
          key          => {
            'id'     => $gpg_key_id,
            'source' => "http://www.beegfs.com/release/beegfs_${_release}/gpg/${_gpg_key}",
          },
          include      => {
            'src' => false,
            'deb' => true,
          },
        }
      }
      default: {
        fail("Unknown package source '${package_source}'")
      }
    }
    Class['apt::update'] -> Package<| tag == 'beegfs' |>
  }
}
