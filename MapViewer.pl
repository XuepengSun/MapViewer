#!/usr/bin/perl
use SVG;
use Getopt::Long;
use List::Util qw(min max sum);

my ($synInput,$gapInput,$mapInput,$help,%chr_MAP,$svg,$group,%texts,%tar_chr_size,%ref_chr_size,%map_size,@right_most);

GetOptions ("syn=s" => \$synInput,    # synteny file, can be none
            "map=s" => \$mapInput,   # string
			"gap=s" => \$gapInput,
            "help"  => \$help)   	 # flag
or die("Error in command line arguments\n");

unless(($synInput || $mapInput) && !$help && $gapInput ){print <DATA>;exit}

###################### parameters for display ##################
# set canvas size
my $canvas_width //= 1500;
my $canvas_height //= 1500;

# set chromosome parameters
my $chr_width //= 50;
my $chr_height //= $canvas_height * 2 / 3;     # 2/3 of the canvas height
my $rx //= 30; # roundness of chromosome
my $chr_stroke_width //= 8;
my $chr_fill_opacity //= 0.3;
my $chr_fill_color //= '#39CCCC' ;

# set chromosome gap region parameters #ffa426
my $gap_stroke_color //= "red";
my $gap_stroke_width //= 2;   # miminal width, if smaller then this value will be used
my $gap_stroke_opacity //= 1;
#my $gap_fill_opacity //= 1;

# set genetic map parameters 
my $map_stroke_width //= 8;   # straight line and top/bottom lines
my $map_inner_stroke_width //= 0.5;
my $tick_opc //= 1;
my $tick_width //= 40;

# set synteny block parameters
my $synteny_fill_color //= "grey";
my $synteny_region_stroke_opa = 0;
my $synteny_fill_opac = 0.2;

# set link parameters
my $link_stroke_width //= 1;
my $link_stroke_opc //= 0.3;

#set text parameters
my $scale_font_size //= 30;
my $scale_dist_to_plot //= 20;
my $text_font //= "Arial";
my $text_font_size //= 40;
my $text_color //= "#696969";
my $text_dist_to_plot //= 30;
my $text_ver_dist_to_plot //= 80;

# set chromosome position
my $chr_pos_on_x //=  $canvas_width / 2 ;    # middle of the canvas;
my $chr_pos_on_y //= 20;	# can be 0

# set panel horizontal distance to chromosome
my $hor_dist_to_chr //= 400;

# set vertical gap distance
my $ver_dist_between_obj = 50;

# set colors for each panel, can be rearranged
my @colors = ("#EE5C42","#27D683","#FFA500","#E94B3C","#ECDB54");

# set display
my $middle_point //= "F";   # straight link or not 
my $remove_file_suffix = 'T';
my $add_chr_scale = 'T';

# set chromosome scalar 
my $chr_scale_dist_to_left = 70;
my $chr_scale_main_tick_width = 30;
my $chr_scale_minor_tick_width = 15;
my $chr_scale_main_font_size = 30;
my $chr_scale_stroke_width = 4;
my $chr_scale_stroke_color = "grey";
my $chr_scale_stroke_opacity = 1;
my $chr_scale_num_dist = 30;
my $chr_scale_col = "#696969";
my $chr_base = 1000000;    # if kb set 1000


##########################################################

my @synFiles = split(/,/,$synInput) if $synInput;
my @gmapFiles = split(/,/,$mapInput) if $mapInput;

# arrange panels to plot
my (@left_panel,@right_panel);

if($synInput && $mapInput){
	@left_panel = sort @gmapFiles;
	@right_panel = sort @synFiles ;
}
else{
	my @tmp;
	push @tmp,@synFiles if $synInput;
	push @tmp,@gmapFiles if $mapInput;
	my $int = scalar (@tmp) % 2 == 0 ? scalar (@tmp) / 2 : int(scalar (@tmp) / 2) + 1;
	@left_panel = splice(@tmp,0,$int);
	@right_panel = @tmp;
}

my ($left_plot,$right_plot,%final_plot);

# process files for left panel
if(@left_panel){
	$left_plot = file_processing(\@left_panel,'left');
	foreach my $c(keys %$left_plot){
		foreach(keys %{$left_plot->{$c}}){
			push @{$final_plot{$c}{$_}},@{$left_plot->{$c}{$_}};
		}
	}
}

# process files for right panel
if(@right_panel){
	$right_plot = file_processing(\@right_panel,'right');
	foreach my $c(keys %$right_plot){
		foreach(keys %{$right_plot->{$c}}){
			push @{$final_plot{$c}{$_}},@{$right_plot->{$c}{$_}};
		}
	}
}

# process gap file 
open GAP,$gapInput || die "cannot open $gapInput $!";
while(<GAP>){
	chomp;
	my @s = split;
	my $y0 = $chr_height * $s[1] / $tar_chr_size{$s[0]} + $chr_pos_on_y;
	my $width = $chr_height*$s[2]/$tar_chr_size{$s[0]} > $gap_stroke_width ? $chr_height*$s[2]/$tar_chr_size{$s[0]}:$gap_stroke_width;
	my $x0 = $chr_pos_on_x;
	my $x1 = $chr_pos_on_x + $chr_width;
	push @{$final_plot{$s[0]}{'line'}},join("_",($x0,$x1,$y0,$y0,$gap_stroke_color,$width,$gap_stroke_opacity,'gap'));
}
close GAP;

## final output
foreach my $chrm(keys %chr_MAP){
	next if !$final_plot{$chrm};
	# initialize SVG object
	$svg = SVG->new(width => $canvas_width, height => $canvas_height);
	$group = $svg -> group( id => "group-$chrm", 
					           style =>{stroke=>'black',fill=>'white','stroke-width'=>'1',
							   'stroke-opacity'=>'0.5','fill-opacity'=>'0'}
	);
	
	if($final_plot{$chrm}{'line'}){
		foreach(@{$final_plot{$chrm}{'line'}}){
			my @s = split(/_/,$_);
			add_line_to_svg(\@s);
		}
	}
	
	if($final_plot{$chrm}{'polyline'}){
		foreach(@{$final_plot{$chrm}{'polyline'}}){
			my @s = split(/_/,$_);
			add_polyline_to_svg(\@s);
		}
	}

	if($final_plot{$chrm}{'rect'}){
		foreach(@{$final_plot{$chrm}{'rect'}}){
			my @s = split(/_/,$_);
			add_rectangle_to_svg(\@s);
		}
	}
	
	if($final_plot{$chrm}{'polygon'}){
		foreach(@{$final_plot{$chrm}{'polygon'}}){
			my @s = split(/_/,$_);
			add_polygon_to_svg(\@s);
		}
	}
	
	# plot chromosome 
	my @chr_param = ($chr_pos_on_x,$chr_pos_on_y,$chr_width,$chr_height,$chr_fill_opacity,$chr_fill_color,$chr_stroke_width);
	add_rectangle_to_svg (\@chr_param);
	
	#plot text
	foreach (keys %{$texts{$chrm}}){
		$add_text = $svg->group(transform =>"translate($texts{$chrm}{$_}->{'x'}, $texts{$chrm}{$_}->{'y'}) rotate($texts{$chrm}{$_}->{'transform'})");
		$add_text -> text('fill' =>$text_color,'font-size'=>$texts{$chrm}{$_}->{'size'},
					style=>{'text-anchor'=>$texts{$chrm}{$_}->{'anchor'}}
					)->cdata($texts{$chrm}{$_}->{'text'});
					
		# store values for scale plot
		push @right_most,$texts{$chrm}{$_}->{'x'};
	}

	#plot text for target chromosome
	my $x = $chr_pos_on_x + $chr_width / 2;
	my $y = $chr_pos_on_y + $chr_height + $text_ver_dist_to_plot;
	
	my $chrSize = sprintf("%.1f",$tar_chr_size{$chrm}/1000000);
	
	$add_text = $svg->group(transform =>"translate($x,$y) rotate(0)");
	$add_text -> text('fill' =>$text_color,'font-size'=>$text_font_size,
					style=>{'text-anchor'=>'middle'}
					)->cdata("$chrm ($chrSize Mb)");
	
	push @right_most,($x,$chr_pos_on_x+$chr_width);
	

	## plot chromosome scalar;
	if($add_chr_scale eq 'T'){
		my $scalar_left_most = max(@right_most) + $chr_scale_dist_to_left;
		my $gn_unit = $tar_chr_size{$chrm} / $chr_base;
		my $diff = (int($gn_unit / 3) + 1) * 3 - $gn_unit;
		my $scalar_length = $diff <= 1 ? (int($gn_unit / 3) + 1) * 3 : int($gn_unit / 3) * 3 ;
		my $scalar_height = $chr_height * $scalar_length / ($tar_chr_size{$chrm}/$chr_base);
		
		my @tick_straight = ($scalar_left_most,$scalar_left_most,$chr_pos_on_y,$chr_pos_on_y+$scalar_height,$chr_scale_stroke_color,$chr_scale_stroke_width,$chr_scale_stroke_opacity,"scalar");
		add_line_to_svg(\@tick_straight);
	
		for (my $i=0;$i<=$scalar_length;$i++){
			if($i % 3 == 0){
				my $chr_tick_x_main = $scalar_left_most + $chr_scale_main_tick_width;
				my $chr_tick_y_main = $scalar_height * $i / $scalar_length + $chr_pos_on_y;
				my @tick_main = ($scalar_left_most,$chr_tick_x_main,$chr_tick_y_main,$chr_tick_y_main,$chr_scale_stroke_color,$chr_scale_stroke_width,$chr_scale_stroke_opacity,"scalar");
				add_line_to_svg(\@tick_main);
				
				# add numbers
				my $t_x = $chr_tick_x_main+$chr_scale_num_dist;
				my $t_y = $chr_tick_y_main + 10;
				$add_text = $svg->group(transform =>"translate($t_x,$t_y) rotate(0)");
				$add_text -> text('fill' =>$chr_scale_col,'font-size'=>$chr_scale_main_font_size,
				style=>{'text-anchor'=>'middle'})->cdata("$i");
			}
			else{
				my $chr_tick_x_minor = $scalar_left_most + $chr_scale_minor_tick_width;
				my $chr_tick_y_minor = $scalar_height * $i / $scalar_length + $chr_pos_on_y;
				my @tick_minor = ($scalar_left_most,$chr_tick_x_minor,$chr_tick_y_minor,$chr_tick_y_minor,$chr_scale_stroke_color,$chr_scale_stroke_width,$chr_scale_stroke_opacity,"scalar");
				add_line_to_svg(\@tick_minor);
			}
		}
	}
	
	open OUT,">$chrm.svg";
	print OUT $svg->xmlify;
	close OUT;
}


sub file_processing{
	my ($all_files,$direction) = @_;
	my (%panel_heights,$data_type,%plot);
	# calculate position of each panel
	foreach my $file(@$all_files){
		my (%h,%corr);
		open IN,$file || die "$!";
		while(<IN>){
			chomp;
			my @s = split /\t/;
			if(scalar @s == 8){
				$data_type = 'synteny';
				$h{$s[0]}{$s[4]} = $chr_height * $s[5] / $s[1] > $canvas_width *0.95 ? $canvas_width *0.9 : $chr_height * $s[5] / $s[1];
				$corr{$s[0]}{$s[4]}++;
				$tar_chr_size{$s[0]}=$s[1];
				$ref_chr_size{$file}{$s[4]} = $s[5];
			}
			elsif(scalar @s == 6){
				$tar_chr_size{$s[0]}=$s[1];
				$data_type = 'map';
				$h{$s[0]}{$s[3]} = $s[4];
				$corr{$s[0]}{$s[3]}++;
				$map_size{$file}{$s[3]} = $s[4];
			}
			else{ print STDERR "\ncheck $file format!\n\n";exit}
		}
		close IN;
		foreach my $chr(keys %corr){
			my @t = sort{$corr{$chr}{$b} <=> $corr{$chr}{$a}} keys %{$corr{$chr}};
			push @{$panel_heights{$chr}}, $h{$chr}{$t[0]};
			$chr_MAP{$chr}{$file} = $t[0];
		}
	}
	
	if($data_type eq 'map'){
		foreach my $chr(keys %panel_heights){
			if(scalar @{$panel_heights{$chr}} == 1){$panel_heights{$chr}[0] = $chr_height}
			else{
				my $total_height = $canvas_height * 0.75 - (scalar @{$panel_heights{$chr}} -1) * $ver_dist_between_obj;  # 3/4 of canvas  
				my $total_cM = sum (@{$panel_heights{$chr}});
				@{$panel_heights{$chr}} = map{$total_height * $_ / $total_cM} @{$panel_heights{$chr}};
			}
		}
	}
	
	my (%tmp_pos,@tmp_col);
	foreach my $chr(keys %panel_heights){
		my $bottom = 0;
		my $up = 0;	
		my $m = -1;
		my $numk = 0;
		my @tmp_colors = @colors;
		foreach my $i(@{$panel_heights{$chr}}){
			$m++;
			my $col = shift @tmp_colors;
			push @tmp_col,$col;
			my $x = $direction eq 'left' ? $chr_pos_on_x-$hor_dist_to_chr : $chr_pos_on_x+$hor_dist_to_chr+$chr_width;
			if($data_type eq 'map'){
				$up = (++$numk -1) * $ver_dist_between_obj + $bottom;
				$bottom = $i + $up ;
				my $y1 = $up + $chr_pos_on_y;
				my $y2 = $bottom + $chr_pos_on_y;
				# x1,x2,y1,y2,stroke,stroke-width,stroke-opacity,tag;
				my $straight_line = join("_",($x,$x,$y1,$y2,$col,$map_stroke_width,$tick_opc,"straight"));
				my $top_line = join("_",($x-$tick_width/2,$x+$tick_width/2,$y1,$y1,$col,$map_stroke_width,$tick_opc,"tick"));
				my $bottom_line = join("_",($x-$tick_width/2,$x+$tick_width/2,$y2,$y2,$col,$map_stroke_width,$tick_opc,"tick"));
				push @{$tmp_pos{$chr}},$y1;
				push @{$plot{$chr}{'line'}},($straight_line,$top_line,$bottom_line);
				# data for text plot
				my $x_text = $direction eq 'left' ? $x - $tick_width - $text_dist_to_plot : $x + $tick_width + $text_dist_to_plot;
				my $x_scale = $direction eq 'left' ? $x - $tick_width / 2 - $scale_dist_to_plot : $x + $tick_width / 2 + $scale_dist_to_plot;
				my $anchor = $direction eq 'left' ? 'end' : 'start';
				my $real_size = sprintf("%.1f",$map_size{$all_files->[$m]}{$chr_MAP{$chr}{$all_files->[$m]}});
				my $file_name_plot = $all_files->[$m];
				if($remove_file_suffix eq 'T'){($file_name_plot)=$file_name_plot=~/(.*)\./}
				$texts{$chr}{$tx++}={'x'=>$x_scale,'y'=>$y1+15,'anchor'=>$anchor,'size'=>$scale_font_size,'text'=>'0','transform'=>0};
				$texts{$chr}{$tx++}={'x'=>$x_scale,'y'=>$y2,'anchor'=>$anchor,'size'=>$scale_font_size,'text'=>"$real_size (cM)",'transform'=>0};
				my $y_middle = ($y1 + $y2) / 2;
				$texts{$chr}{$tx++}={'x'=>$x_text,'y'=>$y_middle,'anchor'=>'middle','size'=>$text_font_size,'text'=>"$chr_MAP{$chr}{$all_files->[$m]} ($file_name_plot)",'transform'=>270};
			}
			else{
				my $y = $chr_pos_on_y;
				my $rect_x = $direction eq 'left' ? $x-$chr_width : $x;
				push @{$plot{$chr}{'rect'}},join("_",($rect_x ,$y,$chr_width,$i,$chr_fill_opacity,$col,$chr_stroke_width));
				#data for text plot
				my $y_text = $y + $i + $text_ver_dist_to_plot;
				my $x_text = $direction eq 'left' ? $x - $chr_width / 2 : $x + $chr_width / 2;
				my $gn_size = sprintf("%.1f",$ref_chr_size{$all_files->[$m]}{$chr_MAP{$chr}{$all_files->[$m]}} / 1000000);
				
				# plot file name
				my $x_file = $direction eq 'left' ? $x - $chr_width - $text_dist_to_plot - 20: $x + $chr_width + $text_dist_to_plot + 20;
				my $y_file = ($y + $i) / 2;
				my $file_name_plot = $all_files->[$m];
				if($remove_file_suffix eq 'T'){($file_name_plot)=$file_name_plot=~/(.*)\./}
				$texts{$chr}{$tx++}={'x'=>$x_file,'y'=>$y_file,'anchor'=>'middle','size'=>$text_font_size,'text'=>"$file_name_plot",'transform'=>90};
				
				$texts{$chr}{$tx++}={'x'=>$x_text,'y'=>$y_text,'anchor'=>'middle','size'=>$text_font_size,'text'=>"$chr_MAP{$chr}{$all_files->[$m]} ($gn_size Mb)",'transform'=>0};
			}
		}
	}
	
	my $j = -1;
	foreach my $f(@$all_files){
		$j++;
		my $color = shift @tmp_col;
		open IN,$f;
		while(<IN>){
			chomp;
			my @s = split /\t/;
			my $x0 = $direction eq 'left' ? $chr_pos_on_x : $chr_pos_on_x + $chr_width;
			my $x1 = $direction eq 'left' ? $x0 - $hor_dist_to_chr : $x0 + $hor_dist_to_chr;
			my $x1_2 = $direction eq 'left' ? $x1 + ($tick_width/2) : $x1 - ($tick_width/2);
			my $xm =  $direction eq 'left' ? $x0 - ($hor_dist_to_chr / 2) : $x0 + ($hor_dist_to_chr / 2);
						
			if(scalar @s == 8){
				next if $chr_MAP{$s[0]}{$f} ne $s[4];
				my $ya0 = $chr_height*$s[2]/$s[1] + $chr_pos_on_y;
				my $ya1 = $chr_height*$s[3]/$s[1] + $chr_pos_on_y;
				my $yb0 = $panel_heights{$s[0]}[$j]*$s[6]/$s[5] + $chr_pos_on_y;
				my $yb1 = $panel_heights{$s[0]}[$j]*$s[7]/$s[5] + $chr_pos_on_y;
				push @{$plot{$s[0]}{'polygon'}}, join("_",($x0,$x1,$x1,$x0,$ya0,$yb0,$yb1,$ya1,$synteny_fill_color,$synteny_region_stroke_opa,$synteny_fill_opac));
			}
			elsif(scalar @s == 6){
				next if $chr_MAP{$s[0]}{$f} ne $s[3];
				$y0 = $chr_height*$s[2]/$s[1] + $chr_pos_on_y;
				$y1 = $panel_heights{$s[0]}[$j]*$s[5]/$s[4] + $tmp_pos{$s[0]}[$j];
				push @{$plot{$s[0]}{'line'}},join("_",($x1-($tick_width/2),$x1+($tick_width/2),$y1,$y1,$color,$map_inner_stroke_width,$tick_opc,'intick'));
				if($middle_point eq 'T'){
					push @{$plot{$s[0]}{'polyline'}}, join("_",($x1_2,$xm,$x0,$y1,$y0,$y0,$color,$link_stroke_width,$link_stroke_opc,"pline"));
				}
				else{
					push @{$plot{$s[0]}{'line'}}, join("_",($x1_2,$x0,$y1,$y0,$color,$link_stroke_width,$link_stroke_opc,"pline"));
				}
			}
			else{next}
		}
		close IN;
	}
	return(\%plot);
}


sub add_line_to_svg{
	my $inline = shift;
	my ($x1,$x2,$y1,$y2,$strok,$stoke_width,$strok_opc,$tag) = @$inline;
	$group->line(
			id => "$tag".++$k,
			x1 => $x1, y1 => $y1,
			x2 => $x2, y2 => $y2,
			style => {
				stroke => $strok, 
				'stroke-width' => $stoke_width,
				'stroke-opacity' => $strok_opc}
	);
}

sub add_polyline_to_svg{
	my $inline = shift;
	my ($x1,$xm,$x0,$y1,$y0,$y0,$strok,$stoke_width,$strok_opc,$tag) = @$inline;
	my $xv = [$x1,$xm,$x0];
	my $yv = [$y1,$y0,$y0];
	my $path = $group->get_path(x=>$xv, y=>$yv,-type=>'polyline',-closed=>'true');
	$group->polyline(%$path,id=>"$tag".++$n, 
					style=>{'stroke'=>$strok,'stroke-width'=>$stoke_width,'stroke-opacity'=>$strok_opc}
	);
}

sub add_polygon_to_svg{
	my $inline = shift;
	my ($x0,$x1,$x1,$x0,$ya0,$yb0,$yb1,$ya1,$col,$stoke_opac,$fill_opa) = @$inline;
	my $xv = [$x0,$x1,$x1,$x0];
	my $yv = [$ya0,$yb0,$yb1,$ya1];
	my $path = $group->get_path(x=>$xv, y=>$yv,-type=>'polygon',-closed=>'true');
	$group->polyline(%$path,id=>"$asdas".++$n,
					style=>{'fill-opacity'=> $fill_opa,'fill'=>$col,'stroke-opacity'=>$stoke_opac}
	);
}

sub add_rectangle_to_svg{
	my $inline = shift;
	my ($x,$y,$width,$height,$fill_opac,$fill,$strok_width) = @$inline;
	$group->rectangle(
			x => $x,
			y => $y,
			width => $width,
			height => $height,
			style=>{'fill-opacity'=> $fill_opac,'fill'=>$fill,'stroke-width'=>$strok_width},
			rx =>$rx,id => 'rect'.++$n
	);
}


__DATA__


version: v0.5 (03/09/2018)

Useage:
	
	perl MapViewer.pl [options]
	
options:
	[input]
		-syn	synteny file name [if set two files, "map" is not allowed; <=2]
		-map	map file name [multiple files can be specified with comma]
		-gap	gap file, gaps between scaffods in the pseudochromosome
		-help	this help information
		
	[display]
			parameters for display can be adjusted within the script
			
	[file format]
		synteny file: 
			<chr_id>\t<chr_length>\t<chr_start>\t<chr_end>\t<ref_chr_id>\t<ref_chr_length>\t<ref_chr_start>\t<ref_chr_end>
		
		map file:
			<chr_id>\t<chr_length>\t<chr_pos>\t<LG_id>\t<LG_distance>\t<LG_position>
			
		gap file:
			<chr_id>\t<gap start position>\t<gap length>
			
			
	
