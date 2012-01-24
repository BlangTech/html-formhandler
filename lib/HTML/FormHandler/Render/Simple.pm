package HTML::FormHandler::Render::Simple;
# ABSTRACT: simple rendering role

use Moose::Role;

requires( 'sorted_fields', 'field' );

use HTML::FormHandler::Render::Util ('process_attrs');

our $VERSION = 0.01;

=head1 SYNOPSIS

This is a Moose role that is an example of a very simple rendering
routine for L<HTML::FormHandler>. It has almost no features, but can
be used as an example for producing something more complex.
The idea is to produce your own custom rendering roles...

You are advised to create a copy of this module for use in your
forms, since it is not possible to make improvements to this module
and maintain backwards compatibility.

In your Form class:

   package MyApp::Form::Silly;
   use Moose;
   extends 'HTML::FormHandler::Model::DBIC';
   with 'HTML::FormHandler::Render::Simple';

In a template:

   [% form.render %]

or for individual fields:

   [% form.render_field( 'title' ) %]


=head1 DESCRIPTION

This role provides HTML output routines for the 'widget' types
defined in the provided FormHandler fields. Each 'widget' name
has a 'widget_$name' method here.

These widget routines output strings with HTML suitable for displaying
form fields.

The widget for a particular field can be defined in the form. You can
create additional widget routines in your form for custom widgets.

The fill-in-form values ('fif') are cleaned with the 'render_filter'
method of the base field class. You can change the filter to suit
your own needs: see L<HTML::FormHandler::Manual::Rendering>

=cut

=head2 render

To render all the fields in a form in sorted order (using
'sorted_fields' method).

=head2 render_start, render_end

Will render the beginning and ending <form> tags and fieldsets. Allows for easy
splitting up of the form if you want to hand-render some of the fields.

   [% form.render_start %]
   [% form.render_field('title') %]
   <insert specially rendered field>
   [% form.render_field('some_field') %]
   [% form.render_end %]

=head2 render_field

Render a field passing in a field object or a field name

   $form->render_field( $field )
   $form->render_field( 'title' )

=head2 render_text

Output an HTML string for a text widget

=head2 render_password

Output an HTML string for a password widget

=head2 render_hidden

Output an HTML string for a hidden input widget

=head2 render_select

Output an HTML string for a 'select' widget, single or multiple

=head2 render_checkbox

Output an HTML string for a 'checkbox' widget

=head2 render_radio_group

Output an HTML string for a 'radio_group' selection widget.
This widget should be for a field that inherits from 'Select',
since it requires the existance of an 'options' array.

=head2 render_textarea

Output an HTML string for a textarea widget

=head2 render_compound

Renders field with 'compound' widget

=head2 render_submit

Renders field with 'submit' widget

=cut

has 'auto_fieldset' => ( isa => 'Bool', is => 'rw', default => 1 );
has 'label_types' => (
    traits    => ['Hash'],
    isa       => 'HashRef[Str]',
    is        => 'rw',
    default   => sub {
        {
            text        => 'label',
            password    => 'label',
            'select'    => 'label',
            checkbox    => 'label',
            textarea    => 'label',
            radio_group => 'label',
            compound    => 'legend',
            upload      => 'label',
            captcha     => 'label',
        };
    },
    handles   => { get_label_type => 'get' },
);

sub render {
    my $self   = shift;
    my $output = $self->render_start;

    $output .= $self->render_form_errors;

    foreach my $field ( $self->sorted_fields ) {
        $output .= $self->render_field($field);
    }

    $output .= $self->render_end;
    return $output;
}

sub render_start {
    my $self   = shift;

    my $output = $self->html_form_tag;

    my $auto_fieldset = $self->tag_exists('no_auto_fieldset') ?
         not( $self->get_tag('no_auto_fieldset') ) : $self->auto_fieldset;
    $output .= '<fieldset class="main_fieldset">'
        if $auto_fieldset;

    return $output
}

sub render_form_errors {
    my $self = shift;

    return '' unless $self->has_form_errors;
    my $output = "\n<div class=\"form_errors\">";
    $output .= qq{\n<span class="error_message">$_</span>}
        for $self->all_form_errors;
    $output .= "\n</div>";
    return $output;
}

sub render_end {
    my $self = shift;

    my $auto_fieldset = $self->tag_exists('no_auto_fieldset') ?
         not( $self->get_tag('no_auto_fieldset') ) : $self->auto_fieldset;
    my $output;
    $output .= '</fieldset>' if $auto_fieldset;
    $output .= "</form>\n";
    return $output;
}

sub render_field {
    my ( $self, $field ) = @_;

    if ( ref( \$field ) eq 'SCALAR' ) {
        $field = $self->field($field);
    }
    die "must pass field to render_field"
        unless ( defined $field && $field->isa('HTML::FormHandler::Field') );
    return '' if $field->widget eq 'no_render';
    my $rendered_field;
    my $form_render = 'render_' . $field->widget;
    if ( $self->can($form_render) ) {
        $rendered_field = $self->$form_render($field);
    }
    elsif ( $field->can('render') ) {
        $rendered_field = $field->render;
    }
    else {
        die "No widget method found for '" . $field->widget . "' in H::F::Render::Simple";
    }
    my $wrapper_attrs = process_attrs($field->wrapper_attributes);
    return $self->render_field_struct( $field, $rendered_field, $wrapper_attrs );
}

sub render_field_struct {
    my ( $self, $field, $rendered_field, $wrapper_attrs ) = @_;
    my $output = qq{\n<div$wrapper_attrs>};
    my $l_type =
        defined $self->get_label_type( $field->widget ) ?
        $self->get_label_type( $field->widget ) :
        '';
    if ( $l_type eq 'label' && $field->label ) {
        $output .= $self->_label($field);
    }
    elsif ( $l_type eq 'legend' ) {
        $output .= '<fieldset class="' . $field->html_name . '">';
        $output .= '<legend>' . $field->html_filter($field->loc_label) . '</legend>';
    }
    $output .= $rendered_field;
    foreach my $error ($field->all_errors){
        $output .= qq{\n<span class="error_message">} . $field->html_filter($error) . '</span>';
    }

    if ( $l_type eq 'legend' ) {
        $output .= '</fieldset>';
    }
    $output .= "</div>\n";
    return $output;
}

sub render_text {
    my ( $self, $field ) = @_;
    my $output = '<input type="' . $field->input_type . '" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= ' size="' . $field->size . '"' if $field->size;
    $output .= ' maxlength="' . $field->maxlength . '"' if $field->maxlength;
    $output .= ' value="' . $field->html_filter($field->fif) . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' />';
    return $output;
}

sub render_password {
    my ( $self, $field ) = @_;
    my $output = '<input type="password" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= ' size="' . $field->size . '"' if $field->size;
    $output .= ' maxlength="' . $field->maxlength . '"' if $field->maxlength;
    $output .= ' value="' . $field->html_filter($field->fif) . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' />';
    return $output;
}

sub render_hidden {
    my ( $self, $field ) = @_;
    my $output = '<input type="hidden" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= ' value="' . $field->html_filter($field->fif) . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' />';
    return $output;
}

sub render_select {
    my ( $self, $field ) = @_;

    my $multiple = $field->multiple;
    my $id = $field->id;
    my $output = '<select name="' . $field->html_name . '"';
    $output .= qq{ id="$id"};
    $output .= ' multiple="multiple"' if $multiple == 1;
    $output .= ' size="' . $field->size . '"' if $field->size;
    my $html_attributes = process_attrs($field->attributes);
    $output .= $html_attributes;
    $output .= '>';
    my $index = 0;
    if( defined $field->empty_select ) {
        $output .= '<option value="">' . $field->_localize($field->empty_select) . '</option>';
    }
    my $fif = $field->fif;
    my %fif_lookup;
    @fif_lookup{@$fif} = () if $multiple;
    foreach my $option ( @{ $field->{options} } ) {
        my $value = $option->{value};
        $output .= '<option value="'
            . $field->html_filter($value)
            . qq{" id="$id.$index"};
        if( defined $option->{disabled} && $option->{disabled} ) {
            $output .= ' disabled="disabled"';
        }
        if ( defined $fif ) {
            if ( $multiple && exists $fif_lookup{$value} ) {
                $output .= ' selected="selected"';
            }
            elsif ( $fif eq $value ) {
                $output .= ' selected="selected"';
            }
        }
        $output .= $html_attributes;
        my $label = $option->{label};
        $label = $field->_localize($label) if $field->localize_labels;
        $output .= '>' . ( $field->html_filter($label) || '' ) . '</option>';
        $index++;
    }
    $output .= '</select>';
    return $output;
}

sub render_checkbox {
    my ( $self, $field ) = @_;

    my $output = '<input type="checkbox" name="' . $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= ' value="' . $field->html_filter($field->checkbox_value) . '"';
    $output .= ' checked="checked"' if $field->fif eq $field->checkbox_value;
    $output .= process_attrs($field->attributes);
    $output .= ' />';
    return $output;
}

sub render_radio_group {
    my ( $self, $field ) = @_;

    my $output = " <br />";
    my $index  = 0;
    foreach my $option ( @{ $field->options } ) {
        my $id = $field->id . ".$index";
        $output .= qq{<label for="$id"><input type="radio" value="} . $field->html_filter($option->{value}) . '"';
        $output .= ' name="' . $field->html_name . '" id="' . "$id\"";
        $output .= ' checked="checked"' if $option->{value} eq $field->fif;
        $output .= ' />';
        $output .= $field->html_filter($option->{label}) . '</label><br />';
        $index++;
    }
    return $output;
}

sub render_textarea {
    my ( $self, $field ) = @_;
    my $fif  = $field->fif || '';
    my $id   = $field->id;
    my $cols = $field->cols || 10;
    my $rows = $field->rows || 5;
    my $name = $field->html_name;

    my $output =
        qq(<textarea name="$name" id="$id" )
        . process_attrs($field->attributes)
        . qq(rows="$rows" cols="$cols">)
        . $field->html_filter($fif)
        . q(</textarea>);

    return $output;
}

sub render_upload {
    my ( $self, $field ) = @_;

    my $output;
    $output = '<input type="file" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' />';
    return $output;
}

sub _label {
    my ( $self, $field ) = @_;

    my $attrs = process_attrs( $field->label_attributes );
    my $label = $field->html_filter($field->loc_label);
    $label .= ": " unless $field->get_tag('label_no_colon');
    return qq{<label$attrs for="} . $field->id . qq{">$label</label>};
}

sub render_compound {
    my ( $self, $field ) = @_;

    my $output = '';
    foreach my $subfield ( $field->sorted_fields ) {
        $output .= $self->render_field($subfield);
    }
    return $output;
}

sub render_submit {
    my ( $self, $field ) = @_;

    my $output = '<input type="submit" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' value="' . $field->html_filter($field->_localize($field->value)) . '" />';
    return $output;
}

sub render_reset {
    my ( $self, $field ) = @_;

    my $output = '<input type="reset" name="';
    $output .= $field->html_name . '"';
    $output .= ' id="' . $field->id . '"';
    $output .= process_attrs($field->attributes);
    $output .= ' value="' . $field->html_filter($field->value) . '" />';
    return $output;
}

sub render_captcha {
    my ( $self, $field ) = @_;

    my $output .= '<img src="' . $self->captcha_image_url . '"/>';
    $output .= '<input id="' . $field->id . '" name="';
    $output .= $field->html_name . '">';
    return $output;
}


use namespace::autoclean;
1;

