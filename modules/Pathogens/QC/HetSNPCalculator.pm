package Pathogens::QC::HetSNPCalculator;

use Moose;
use Utils;
use File::Spec;

#executables
has 'samtools' => ( is => 'ro', isa => 'Str', required => 1 );
has 'bcftools' => ( is => 'ro', isa => 'Str', required => 1 );

#bcftools filters
has 'min_rawReadDepth' => ( is => 'ro', isa => 'Str', required => 1 );
has 'min_hqNonRefBases' => ( is => 'ro', isa => 'Str', required => 1 );
has 'rawReadDepth_hqNonRefBases_ratio' => ( is => 'ro', isa => 'Str', required => 1 );
has 'min_qual' => ( is => 'ro', isa => 'Str', required => 1 );
has 'hqRefReads_hqAltReads_ratio' => ( is => 'ro', isa => 'Str', required => 1 );

#Misc info
has 'fa_ref' => ( is => 'ro', isa => 'Str', required => 1 );
has 'reference_size' => ( is => 'ro', isa => 'Str', required => 1 );
has 'lane_path' => ( is => 'ro', isa => 'Str', required => 1 );
has 'lane' => ( is => 'ro', isa => 'Str', required => 1 );
has 'sample_dir' => ( is => 'ro', isa => 'Str', required => 1 );
has 'heterozygosity_report_file_name' => ( is => 'ro', isa => 'Str', required => 1 );

has 'full_path' => ( is => 'rw', isa => 'Str', lazy => 1, builder => 'build_full_path' );
has 'mpileup_command' => ( is => 'rw', isa => 'Str', lazy => 1, builder => 'build_mpileup_command' );
has 'total_number_of_snps_command' => ( is => 'rw', isa => 'Str', lazy => 1, builder => 'build_total_number_of_snps_command' );
has 'snp_call_command' => ( is => 'rw', isa => 'Str', lazy => 1, builder => 'build_snp_call_command' );
has 'bcf_query_command' => ( is => 'rw', isa => 'Str', lazy => 1, builder => 'build_bcf_query_command' );

sub build_full_path {

  my ($self) = @_;
  my $full_path = File::Spec->catfile( $self->lane_path, $self->sample_dir );
  return($full_path);
}

sub _file_path {

  my ($self,$suffix) = @_;
  my $path = File::Spec->catfile( $self->full_path, $self->{lane} . $suffix );
  return($path);
}

sub build_mpileup_command {

  my ($self) = @_;

  my $bam_file = _file_path( $self, q(.bam) );
  my $temp_vcf = _file_path( $self, q(_temp_vcf.vcf.gz) );
  my $cmd = $self->samtools;
  $cmd .= q( mpileup -d 500 -t INFO/DPR,DV -C50 -ugf );
  $cmd .= $self->fa_ref;
  $cmd .= q( );
  $cmd .= $bam_file;
  $cmd .= q( | bgzip > );
  $cmd .= $temp_vcf;

  return($cmd);
}


sub build_total_number_of_snps_command {

  my ($self) = @_;

  my $temp_vcf = _file_path( $self, q(_temp_vcf.vcf.gz) );
  my $total_number_of_snps = _file_path( $self, q(_total_number_of_snps.csv) );

  my $cmd = $self->{bcftools};
  $cmd .= q( query -f "%CHROM\n");
  $cmd .= q( -i "DP > 0" );
  $cmd .= $temp_vcf;
  $cmd .= q( > );
  $cmd .= $total_number_of_snps;

  return($cmd);
}


sub build_snp_call_command {

  my ($self) = @_;

  my $temp_vcf = _file_path( $self, q(_temp_vcf.vcf.gz) );
  my $snp_called_vcf = _file_path( $self, q(_snp_called.vcf.gz) );

  my $cmd = $self->bcftools;
  $cmd .= q( call -vm -O z );
  $cmd .= $temp_vcf;
  $cmd .= q( > );
  $cmd .= $snp_called_vcf;

  return($cmd);
}


sub build_bcf_query_command {

  my ($self) = @_;

  my $snp_called_vcf = _file_path( $self, q(_snp_called.vcf.gz) );
  my $filtered_snp_called_vcf = _file_path( $self, q(_filtered_snp_called_list.csv) );

  my $cmd = $self->{bcftools} . q( query -f);
  $cmd .= q{ "%CHROM %POS\n" -i};
  $cmd .= q{ "MIN(DP) >= } . $self->{min_rawReadDepth};
  $cmd .= q{ & MIN(DV) >= } . $self->{min_hqNonRefBases};
  $cmd .= q{ & MIN(DV/DP)>= } . $self->{rawReadDepth_hqNonRefBases_ratio};
  $cmd .= q{ & QUAL >= } . $self->{min_qual};
  $cmd .= q{ & (GT='1/0' | GT='0/1' | GT='1/2')};
  $cmd .= q{ & ((DP4[0]+DP4[1])/(DP4[2]+DP4[3]) > } . $self->{hqRefReads_hqAltReads_ratio} . q{)" };
  $cmd .= $snp_called_vcf;
  $cmd .= q{ > } . $filtered_snp_called_vcf;

  return($cmd);
}

sub get_total_number_of_snps {

  my ($self) = @_;
  my $total_number_of_snps = _file_path( $self, q(_total_number_of_snps.csv) );
  my $cmd = $self->total_number_of_snps_command;
  my $exit_code = Utils::CMD($cmd);

  open (my $fh, '<', $total_number_of_snps) or die "$total_number_of_snps: $!";
  return( _count_file_rows($self,$fh) );
}

sub _count_file_rows {

  my ($self,$fh) = @_;
  my $number_of_rows = 0;
  while( my $row = <$fh> ) {
    chomp($row);
    if($row && $row ne q()) {
      $number_of_rows++;
    }
  }
  close($fh);
  return $number_of_rows;
}

sub get_number_of_het_snps {

  my ($self) = @_;


}

sub calculate_percentage {

  my ($self) = @_;

}

sub write_het_report {

  my ($self) = @_;

}

no Moose;
__PACKAGE__->meta->make_immutable;
1;