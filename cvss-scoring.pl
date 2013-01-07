#!/usr/bin/env perl
##############################################################################
#
##############################################################################
#Possible Values:
#For meaning of these values see the official CVSS FAQ at:
#    https://www.first.org/cvss/faq/#c7
#
#Base Score:
#
#AccessVector           Local, Remote
#AccessComplexity       Low, High
#Authentication         Required, Not-Required
#ConfidentialityImpact  None, Partial, Complete
#IntegrityImpact        None, Partial, Complete
#AvailabilityImpact     None, Partial, Complete
#####
#Temporal Score:
#
#Exploitability         Unproven, Proof-of-Concept, Functional, High
#RemediationLevel       Official-Fix, Temporary-Fix, Workaround, Unavailable
#ReportConfidence       Unconfirmed, Uncorroborated, Confirmed
#####
#Environmental Score:
#
#CollateralDamagePotential  None, Low, Medium, High
#TargetDistribution         None, Low, Medium, High
##############################################################################

use Security::CVSS;

my $CVSS = new Security::CVSS;

$CVSS->AccessVector('Local');
$CVSS->AccessComplexity('High');
$CVSS->Authentication('Not-Required');
$CVSS->ConfidentialityImpact('Complete');
$CVSS->IntegrityImpact('Complete');
$CVSS->AvailabilityImpact('Complete');
$CVSS->ImpactBias('Normal');

my $BaseScore = $CVSS->BaseScore();

$CVSS->Exploitability('Proof-Of-Concept');
$CVSS->RemediationLevel('Official-Fix');
$CVSS->ReportConfidence('Confirmed');

my $TemporalScore = $CVSS->TemporalScore()

$CVSS->CollateralDamagePotential('None');
$CVSS->TargetDistribution('None');

my $EnvironmentalScore = $CVSS->EnvironmentalScore();

my $CVSS = new CVSS({AccessVector => 'Local',
                     AccessComplexity => 'High',
                     Authentication => 'Not-Required',
                     ConfidentialityImpact => 'Complete',
                     IntegrityImpact => 'Complete',
                     AvailabilityImpact => 'Complete',
                     ImpactBias => 'Normal'
                  });

my $BaseScore = $CVSS->BaseScore();

$CVSS->UpdateFromHash({AccessVector => 'Remote',
                       AccessComplexity => 'Low');

my $NewBaseScore = $CVSS->BaseScore();

$CVSS->Vector('(AV:L/AC:H/Au:NR/C:N/I:P/A:C/B:C)');
my $BaseScore = $CVSS->BaseScore();
my $Vector = $CVSS->Vector();
