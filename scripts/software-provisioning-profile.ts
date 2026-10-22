/** The accepted profile is fixed; diagnostics may measure bounded alternatives. */
export function softwareProvisioningCpus(diagnostic: boolean, input?: string): number {
  if (!diagnostic || input === undefined) return 4
  if (!/^[1-4]$/.test(input)) throw new Error('Software diagnostic virtual CPUs must be an integer from 1 to 4')
  return Number(input)
}
