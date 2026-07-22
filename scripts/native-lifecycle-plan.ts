export interface LifecycleCommand {
  name: string
  argv: string[]
}

export function macOSRollbackPlan(app: string, identifier: string, previousPackage: string): LifecycleCommand[] {
  return [
    { name: 'remove current application before rollback', argv: ['sudo', 'rm', '-rf', app] },
    { name: 'forget current receipt before rollback', argv: ['sudo', 'pkgutil', '--forget', identifier] },
    { name: 'rollback to v1', argv: ['sudo', 'installer', '-pkg', previousPackage, '-target', '/'] },
  ]
}
